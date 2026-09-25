import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/backup_service.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/main.dart';
import 'package:music_hub/portability_screen.dart';
import 'package:music_hub/sheet_view.dart';
import 'package:music_hub/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'preview_support.dart';

class FakeFiles extends LibraryFileDialogs {
  File? selected;
  bool saved = false, fail = false;
  String? text, name;
  @override
  Future<File?> pick(String kind) async => selected;
  @override
  Future<bool> save(File file, String name) async {
    this.name = name;
    text = await file.readAsString();
    if (fail) throw const FileSystemException('failed');
    return saved;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'Performance text reflows vertically and supports small through moderate sizes',
    (tester) async {
      await preparePreview(tester);
      final song = SongDocument(
        title: 'Performance',
        text:
            '${'A long lyric line with spaces  ' * 10}\n\n{Am} ${'unbroken' * 20}\n${'C      G      Am     F  ' * 6}',
      );
      await tester.pumpWidget(
        previewHost(
          MaterialApp(
            home: PerformanceScreen(song: song, manageWakeLock: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PerformanceSheet>(find.byType(PerformanceSheet)).size,
        18,
      );
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Smaller text'));
        await tester.pump();
      }
      expect(
        tester.widget<PerformanceSheet>(find.byType(PerformanceSheet)).size,
        8,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Smaller text',
              ),
            )
            .onPressed,
        isNull,
      );
      await capturePreview(tester, 'v1-performance-small');
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byTooltip('Larger text'));
        await tester.pump();
      }
      expect(
        tester.widget<PerformanceSheet>(find.byType(PerformanceSheet)).size,
        32,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Larger text',
              ),
            )
            .onPressed,
        isNull,
      );
      for (final scroll in tester.widgetList<Scrollable>(
        find.byType(Scrollable),
      )) {
        expect(scroll.axisDirection, AxisDirection.down);
      }
      expect(tester.takeException(), isNull);
      await capturePreview(tester, 'v1-performance-wrap');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Song text export handles save cancellation and failures honestly',
    (tester) async {
      await preparePreview(tester);
      sqfliteFfiInit();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('export_ui_'),
      ))!;
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: '${root.path}/db',
        ),
      ))!;
      final song = SongDocument(
        title: 'Test',
        text: '  preserved\n{Am}  words',
      );
      await tester.runAsync(() => store.save(song));
      final dialogs = FakeFiles();
      await tester.pumpWidget(
        MaterialApp(
          home: SongExportScreen(
            store: store,
            songId: song.id,
            files: AudioFiles(root),
            dialogs: dialogs,
          ),
        ),
      );
      await flush(tester);
      await tester.pumpAndSettle();
      // The OS dialog is fake; text files and SQLite operations are real.
      await tester.tap(find.text('Chords/Lyrics (.txt)'));
      await flush(tester);
      expect(find.text('Export cancelled.'), findsOneWidget);
      expect(dialogs.text, song.text);
      expect(dialogs.name, 'Test-Chords-Lyrics.txt');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      dialogs.saved = true;
      await tester.tap(find.text('Chords/Lyrics (.txt)'));
      await flush(tester);
      expect(find.text('Text exported.'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      dialogs.fail = true;
      await tester.tap(find.text('Chords/Lyrics (.txt)'));
      await flush(tester);
      expect(find.textContaining('Could not complete'), findsOneWidget);
      expect(find.text('Text exported.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(store.close);
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets(
    'restore previews replacement, cancel retains current Song, confirmed restore replaces',
    (tester) async {
      await preparePreview(tester);
      sqfliteFfiInit();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('restore_ui_'),
      ))!;
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: '${root.path}/db',
        ),
      ))!;
      final files = AudioFiles(root), dialogs = FakeFiles();
      final song = SongDocument(title: 'Backed up', text: 'Hello');
      await tester.runAsync(() async {
        await store.save(song);
        dialogs.selected = await BackupService(
          store,
          files,
        ).create(await root.createTemp('zip-'));
        await store.save(
          SongDocument(title: 'Current', text: 'keep unless confirmed'),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    restoreLibrary(context, store, files, dialogs: dialogs),
                child: const Text('Restore'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Restore'));
      await flush(tester);
      // Isolate startup can be slower than ordinary UI file operations.
      for (
        var i = 0;
        i < 15 && find.text('Replace library?').evaluate().isEmpty;
        i++
      ) {
        await flush(tester);
      }
      expect(find.text('Replace library?'), findsOneWidget);
      expect(
        find.textContaining('Restore 1 Songs and 0 recordings'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await flush(tester);
      expect(find.textContaining('Your library is unchanged'), findsOneWidget);
      expect((await tester.runAsync(store.list))!, hasLength(2));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await flush(tester);
      for (
        var i = 0;
        i < 15 && find.text('Replace library?').evaluate().isEmpty;
        i++
      ) {
        await flush(tester);
      }
      await tester.tap(find.text('Replace library'));
      await flush(tester);
      expect(
        find.text('Library restored.'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect((await tester.runAsync(store.list))!.single.id, song.id);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(store.close);
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
