import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/rhythm.dart';
import 'package:music_hub/rhythm_audio.dart';
import 'package:music_hub/rhythm_screen.dart';
import 'package:music_hub/store.dart';
import 'preview_support.dart';

class FakeRhythmAudio implements RhythmAudio {
  final events = StreamController<Duration>.broadcast(),
      interruptionsController = StreamController<void>.broadcast();
  final starts = <RhythmPattern>[];
  int stops = 0;
  bool disposed = false;
  Completer<void>? pending;
  @override
  Stream<Duration> get positions => events.stream;
  @override
  Stream<void> get interruptions => interruptionsController.stream;
  @override
  Future<void> start(RhythmPattern pattern) async {
    starts.add(pattern);
    await pending?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
    await interruptionsController.close();
  }
}

class FlakyStore extends MusicStore {
  FlakyStore(super.db);
  bool fail = false;
  @override
  Future<void> setSetting(String key, String value) async {
    if (fail) throw const FileSystemException('Storage unavailable');
    await super.setSetting(key, value);
  }
}

void main() {
  late MusicStore store;
  late FakeRhythmAudio audio;
  setUpAll(sqfliteFfiInit);
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 45)),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> open(WidgetTester tester, {MusicStore? repository}) async {
    await preparePreview(tester);
    store =
        repository ??
        (await tester.runAsync(
          () => MusicStore.open(
            factory: databaseFactoryFfi,
            location: inMemoryDatabasePath,
          ),
        ))!;
    audio = FakeRhythmAudio();
    await tester.pumpWidget(
      previewHost(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RhythmScreen(store: store, audio: audio),
        ),
      ),
    );
    await flush(tester);
  }

  Future<RhythmPattern> saved(WidgetTester tester) async =>
      RhythmPattern.fromJson(
        jsonDecode(
          (await tester.runAsync<String?>(() => store.setting('rhythm')))!,
        ),
      );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await flush(tester);
    await tester.runAsync(store.close);
  }

  Future<void> block(
    WidgetTester tester,
    int row,
    double portion, {
    bool hold = false,
  }) async {
    final finder = find.byKey(ValueKey('rhythm-row-$row'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final rect = tester.getRect(finder),
        point = Offset(rect.left + rect.width * portion, rect.center.dy);
    if (hold) {
      await tester.longPressAt(point);
    } else {
      await tester.tapAt(point);
    }
    await tester.pump();
  }

  Future<void> divide(
    WidgetTester tester,
    int count, {
    bool cancel = false,
  }) async {
    await tester.tap(find.text('Divide'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem(count - 1);
    await tester.pumpAndSettle();
    final preview = tester.widget<RhythmBlocks>(
      find.descendant(
        of: find.byType(DivideSheet),
        matching: find.byType(RhythmBlocks),
      ),
    );
    expect(rhythmLeaves(preview.root).length, count);
    if (cancel) {
      await tester.tap(find.text('Cancel'));
    } else {
      await tester.tap(
        find.descendant(
          of: find.byType(DivideSheet),
          matching: find.widgetWithText(FilledButton, 'Divide'),
        ),
      );
    }
    await tester.pumpAndSettle();
    await flush(tester);
  }

  testWidgets(
    'wheel preview/cancel, recursive division, merge/undo and saved polyrhythm',
    (tester) async {
      await open(tester);
      expect(find.text('Listen for BPM'), findsNothing);
      await block(tester, 0, 0.5);
      await flush(tester);
      await divide(tester, 7, cancel: true);
      expect((await saved(tester)).rows.single.root.isLeaf, true);
      await divide(tester, 4);
      expect((await saved(tester)).rows.single.root.children.length, 4);
      await block(tester, 0, 0.625, hold: true);
      await divide(tester, 3);
      expect(
        (await saved(tester)).rows.single.root.children[2].children.length,
        3,
      );
      expect(find.text('Whole cycle'), findsOneWidget);
      await tester.tap(find.text('Merge'));
      await flush(tester);
      expect((await saved(tester)).rows.single.root.children[2].isLeaf, true);
      await tester.tap(find.byTooltip('Undo'));
      await flush(tester);
      expect(
        (await saved(tester)).rows.single.root.children[2].children.length,
        3,
      );
      await tester.tap(find.byTooltip('Redo'));
      await flush(tester);
      for (final fraction in [0.375, 0.625, 0.875, 0.125]) {
        await block(tester, 0, fraction);
      }
      await tester.tap(find.text('Add row'));
      await flush(tester);
      await tester.tap(find.byKey(const ValueKey('sound-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kick').last);
      await tester.pumpAndSettle();
      await block(tester, 1, 0.5);
      await divide(tester, 3);
      await block(tester, 1, 0.5);
      await block(tester, 1, 0.85);
      await flush(tester);
      final pattern = await saved(tester);
      expect(pattern.rows.length, 2);
      expect(rhythmLeaves(pattern.rows[0].root).map((l) => l.hit), [
        2,
        1,
        1,
        1,
      ]);
      expect(pattern.rows[1].sound, RhythmSound.kick);
      expect(rhythmLeaves(pattern.rows[1].root).map((l) => l.hit), [1, 1, 1]);
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(audio.starts.last.rows.length, 2);
      audio.events.add(const Duration(milliseconds: 500));
      await tester.pump();
      await capturePreview(tester, 'rhythm-editor');
      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(audio.stops, 1);
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
      expect(audio.disposed, true);
      audio = FakeRhythmAudio();
      await tester.pumpWidget(
        MaterialApp(
          home: RhythmScreen(store: store, audio: audio),
        ),
      );
      await flush(tester);
      expect(
        tester
            .widget<RhythmBlocks>(find.byKey(const ValueKey('rhythm-row-1')))
            .root
            .toJson(),
        pattern.rows[1].root.toJson(),
      );
      expect(audio.starts, isEmpty);
      await close(tester);
    },
  );
  testWidgets(
    'stop/background/interruption cancel preparing playback and never auto-resume',
    (tester) async {
      await open(tester);
      audio.pending = Completer<void>();
      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(find.text('Stop (preparing…)'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      audio.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
      expect(audio.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(audio.starts.length, 1);
      audio.pending = null;
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      audio.interruptionsController.add(null);
      await tester.pumpAndSettle();
      expect(find.textContaining('Audio interrupted'), findsOneWidget);
      await close(tester);
      expect(audio.disposed, true);
    },
  );
  testWidgets(
    'save failure retains edits, retry persists, corrupted state is not overwritten',
    (tester) async {
      final backing = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: inMemoryDatabasePath,
        ),
      ))!;
      final flaky = FlakyStore(backing.db);
      await open(tester, repository: flaky);
      flaky.fail = true;
      await block(tester, 0, 0.5);
      await flush(tester);
      expect(find.textContaining('Rhythm not saved'), findsOneWidget);
      expect(
        tester
            .widget<RhythmBlocks>(find.byKey(const ValueKey('rhythm-row-0')))
            .root
            .hit,
        1,
      );
      flaky.fail = false;
      await tester.tap(find.text('Retry save'));
      await flush(tester);
      expect((await saved(tester)).rows.single.root.hit, 1);
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
      await tester.runAsync(
        () => store.setSetting('rhythm', '{"formatVersion":999}'),
      );
      audio = FakeRhythmAudio();
      await tester.pumpWidget(
        MaterialApp(
          home: RhythmScreen(store: store, audio: audio),
        ),
      );
      await flush(tester);
      expect(
        find.textContaining('Could not read the saved rhythm'),
        findsOneWidget,
      );
      expect(find.text('Add row'), findsNothing);
      expect(
        await tester.runAsync<String?>(() => store.setting('rhythm')),
        '{"formatVersion":999}',
      );
      await close(tester);
    },
  );
  testWidgets(
    'Back waits for save, preserves failed edits, then exits after retry',
    (tester) async {
      await preparePreview(tester);
      final backing = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: inMemoryDatabasePath,
        ),
      ))!;
      final flaky = FlakyStore(backing.db);
      store = flaky;
      audio = FakeRhythmAudio();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RhythmScreen(store: store, audio: audio),
                  ),
                ),
                child: const Text('Open Rhythm'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Rhythm'));
      await flush(tester);
      await tester.pumpAndSettle();
      flaky.fail = true;
      await block(tester, 0, 0.5);
      await flush(tester);
      await tester.pageBack();
      await flush(tester);
      expect(find.byType(RhythmScreen), findsOneWidget);
      expect(find.textContaining('Rhythm not saved'), findsOneWidget);
      flaky.fail = false;
      await tester.pageBack();
      await flush(tester);
      await tester.pumpAndSettle();
      expect(find.text('Open Rhythm'), findsOneWidget);
      expect(audio.disposed, true);
      expect((await saved(tester)).rows.single.root.hit, 1);
      await close(tester);
    },
  );
  testWidgets(
    'iOS wheel handles all integers with selection haptics and narrow layout',
    (tester) async {
      await open(tester);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.physicalSize = const Size(320, 844);
      await block(tester, 0, 0.5, hold: true);
      await tester.tap(find.text('Divide'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -108));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      expect(picker.scrollController!.selectedItem, greaterThan(3));
      expect(haptics, contains('HapticFeedbackType.selectionClick'));
      picker.scrollController!.jumpToItem(15);
      await tester.pumpAndSettle();
      await capturePreview(tester, 'rhythm-divide-wheel');
      await tester.tap(
        find.descendant(
          of: find.byType(DivideSheet),
          matching: find.widgetWithText(FilledButton, 'Divide'),
        ),
      );
      await tester.pumpAndSettle();
      await flush(tester);
      expect((await saved(tester)).rows.single.root.children.length, 16);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
      await close(tester);
    },
  );
}
