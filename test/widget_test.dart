import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:music_hub/document.dart';
import 'package:music_hub/delete_action.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:record/record.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/main.dart';
import 'package:music_hub/store.dart';
import 'package:music_hub/sheet_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'paste an entire sheet, edit, save, reopen and perform without line controls',
    (tester) async {
      sqfliteFfiInit();
      final screenshotDirectory = Platform.environment['MUSIC_HUB_SCREENSHOTS'];
      final boundaryKey = GlobalKey();
      if (screenshotDirectory != null) {
        await tester.runAsync(() async {
          for (final font in {
            'Roboto': '/System/Library/Fonts/SFNS.ttf',
            'Courier': '/System/Library/Fonts/Courier.ttc',
            'MaterialIcons':
                '${Platform.environment['FLUTTER_ROOT'] ?? '/Applications/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          }.entries) {
            final loader = FontLoader(font.key);
            loader.addFont(
              File(
                font.value,
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            );
            await loader.load();
          }
        });
      }
      Future<void> capture(String name) async {
        if (screenshotDirectory == null) {
          return;
        }
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(screenshotDirectory).create(recursive: true);
          await File(
            '$screenshotDirectory/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('music_widget_'),
      ))!;
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: '${root.path}/db.sqlite',
        ),
      ))!;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/wakelock'),
            (call) async => null,
          );
      Future<void> settleIo() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MusicHub(store: store, files: AudioFiles(root)),
        ),
      );
      await settleIo();
      expect(find.text('Record'), findsOneWidget);
      await tester.tap(find.text('New song'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('title')), 'Porch light');
      const text =
          '[Intro]\nC       Em   Am Am\nWise men say\n       {F}         C      G G\n\nLast line\n';
      await tester.enterText(find.byKey(const Key('sheet-text')), text);
      expect(find.text('Add lyric line'), findsNothing);
      final field = tester.widget<TextField>(
        find.byKey(const Key('sheet-text')),
      );
      expect(field.controller!.text, text);
      await tester.tap(find.text('Save'));
      await settleIo();
      expect(find.text('Saved on this device'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await capture('editor');
      await tester.tap(find.byTooltip('Back to songs'));
      await settleIo();
      await capture('songs');
      await tester.tap(find.text('Porch light'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('sheet-text')))
            .controller!
            .text,
        text,
      );
      await tester.tap(find.byTooltip('Performance mode'));
      await tester.pumpAndSettle();
      expect(find.byType(PerformanceScreen), findsOneWidget);
      expect(
        tester
            .widget<PerformanceScreen>(find.byType(PerformanceScreen))
            .song
            .text,
        text,
      );
      expect(find.text('F'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await capture('performance');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    },
  );
  testWidgets('Record is one tap away and denial creates no empty recording', (
    tester,
  ) async {
    sqfliteFfiInit();
    final previous = RecordPlatform.instance;
    final denied = DeniedRecorder();
    RecordPlatform.instance = denied;
    addTearDown(() {
      RecordPlatform.instance = previous;
    });
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('audio_ui_'),
    ))!;
    final files = AudioFiles(root);
    final store = (await tester.runAsync(
      () => MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      ),
    ))!;
    await tester.pumpWidget(MusicHub(store: store, files: files));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(denied.requests, 0);
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(denied.requests, 1);
    expect(find.textContaining('Microphone access is off'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect((await tester.runAsync(files.pending))!, isEmpty);
    expect((await tester.runAsync(store.recordings))!, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await store.close();
      await root.delete(recursive: true);
    });
  });

  testWidgets('backgrounding finalizes capture and keeps a recoverable draft', (
    tester,
  ) async {
    sqfliteFfiInit();
    final previous = RecordPlatform.instance;
    final fake = CapturingRecorder();
    RecordPlatform.instance = fake;
    addTearDown(() {
      RecordPlatform.instance = previous;
    });
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('capture_ui_'),
    ))!;
    final files = AudioFiles(root);
    final store = (await tester.runAsync(
      () => MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      ),
    ))!;
    Future<void> flushIo() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    await tester.pumpWidget(MusicHub(store: store, files: files));
    await flushIo();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pump();
    for (var attempt = 0; attempt < 20 && !fake.recording; attempt++) {
      await flushIo();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.recording, true);
    expect(find.text('Listening…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    for (var attempt = 0; attempt < 10; attempt++) {
      await flushIo();
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fake.recording, false);
    expect(fake.stops, 1);
    expect(find.text('Save recording'), findsOneWidget);
    final pending = (await tester.runAsync(files.pending))!;
    expect(pending, hasLength(1));
    expect(
      await tester.runAsync(
        () => files.draftAudio(pending.single).readAsBytes(),
      ),
      [2, 4, 6, 8],
    );
    expect((await tester.runAsync(store.recordings))!, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await store.close();
      await root.delete(recursive: true);
    });
  });

  testWidgets(
    'swipe reveals trash; cancel preserves song; detail delete removes it',
    (tester) async {
      sqfliteFfiInit();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('delete_ui_'),
      ))!;
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: '${root.path}/db.sqlite',
        ),
      ))!;
      await tester.runAsync(
        () => store.save(SongDocument(title: 'Delete this song')),
      );
      await tester.pumpWidget(MusicHub(store: store, files: AudioFiles(root)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SwipeDelete), const Offset(-150, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Song?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(store.list))!, hasLength(1));
      await tester.tap(find.text('Delete this song'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Saved versions'), findsNothing);
      await tester.tap(find.text('Delete Song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect((await tester.runAsync(store.list))!, isEmpty);
      expect(find.text('Delete this song'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    },
  );

  testWidgets('tuner decodes split PCM chunks, shows pitch and stops on exit', (
    tester,
  ) async {
    sqfliteFfiInit();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tunerBoundary = GlobalKey();
    final old = RecordPlatform.instance, fake = StreamingRecorder();
    RecordPlatform.instance = fake;
    addTearDown(() {
      RecordPlatform.instance = old;
    });
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('tuner_ui_'),
    ))!;
    final store = (await tester.runAsync(
      () => MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      ),
    ))!;
    await tester.pumpWidget(
      RepaintBoundary(
        key: tunerBoundary,
        child: MusicHub(store: store, files: AudioFiles(root)),
      ),
    );
    await tester.tap(find.text('Tuner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(fake.recording, true);
    final bytes = ByteData(8192);
    for (var i = 0; i < 4096; i++) {
      bytes.setInt16(
        i * 2,
        (12000 * math.sin(2 * math.pi * 110 * i / 22050)).round(),
        Endian.little,
      );
    }
    final data = bytes.buffer.asUint8List();
    fake.input.add(Uint8List.sublistView(data, 0, 301));
    fake.input.add(Uint8List.sublistView(data, 301));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('In tune'), findsOneWidget);
    expect(find.text('A2'), findsNWidgets(2));
    final screenshots = Platform.environment['MUSIC_HUB_SCREENSHOTS'];
    if (screenshots != null) {
      await tester.runAsync(() async {
        final boundary =
            tunerBoundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final rendered = await boundary.toImage(pixelRatio: 2);
        final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$screenshots/tuner.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        rendered.dispose();
      });
    }

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(fake.recording, false);
    await tester.runAsync(() async {
      await store.close();
      await root.delete(recursive: true);
    });
  });

  testWidgets('recording swipe deletion confirms and removes saved take', (
    tester,
  ) async {
    sqfliteFfiInit();
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('delete_take_'),
    ))!;
    final store = (await tester.runAsync(
      () => MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      ),
    ))!;
    await tester.runAsync(
      () => store.saveRecording(
        id: 'take',
        title: 'Test take',
        hash: 'hash',
        relativePath: 'audio.m4a',
        durationMs: 1000,
        createdAt: '',
      ),
    );
    await tester.pumpWidget(MusicHub(store: store, files: AudioFiles(root)));
    await tester.tap(find.text('Recordings'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SwipeDelete), const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Recording?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect((await tester.runAsync(store.recordings))!, isEmpty);
    expect(find.text('Test take'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await store.close();
      await root.delete(recursive: true);
    });
  });

  testWidgets('highlighting preserves editable text and IME composition', (
    tester,
  ) async {
    final controller = SheetController(text: '  {Am} words\n[Verse]\n');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(),
              withComposing: true,
            );
            expect(span.toPlainText(), controller.text);
            controller.value = controller.value.copyWith(
              composing: const TextRange(start: 3, end: 5),
            );
            expect(
              controller
                  .buildTextSpan(context: context, withComposing: true)
                  .toPlainText(),
              controller.text,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    controller.dispose();
  });
}

class DeniedRecorder extends RecordPlatform {
  int requests = 0;
  @override
  Future<void> create(String recorderId) async {}
  @override
  Future<void> dispose(String recorderId) async {}
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    requests++;
    return false;
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class CapturingRecorder extends DeniedRecorder {
  final states = StreamController<RecordState>.broadcast();
  String? path;
  bool recording = false;
  int stops = 0;
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      true;
  @override
  Stream<RecordState> onStateChanged(String recorderId) => states.stream;
  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    this.path = path;
    await File(path).writeAsBytes([2, 4, 6, 8]);
    recording = true;
    states.add(RecordState.record);
  }

  @override
  Future<String?> stop(String recorderId) async {
    stops++;
    recording = false;
    states.add(RecordState.stop);
    return path;
  }

  @override
  Future<bool> isRecording(String recorderId) async => recording;
  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -20, max: -10);
  @override
  Future<void> dispose(String recorderId) async {
    await states.close();
  }
}

class StreamingRecorder extends CapturingRecorder {
  final input = StreamController<Uint8List>();
  @override
  Future<void> setOnConfigChanged(
    String recorderId,
    void Function(RecordConfig)? callback,
  ) async {}
  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    recording = true;
    states.add(RecordState.record);
    return input.stream;
  }

  @override
  Future<void> dispose(String recorderId) async {
    recording = false;
    await input.close();
    await super.dispose(recorderId);
  }
}
