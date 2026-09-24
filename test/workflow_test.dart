import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/audio_screen.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/main.dart';
import 'package:music_hub/recording.dart';
import 'package:music_hub/store.dart';
import 'preview_support.dart';

class FakePlayback extends Fake implements AudioPlayer {
  bool isPlaying = false, disposed = false;
  Duration positionValue = Duration.zero;
  final clips = <(Duration?, Duration?)>[];
  LoopMode mode = LoopMode.off;
  @override
  bool get playing => isPlaying;
  @override
  Duration? get duration => const Duration(seconds: 10);
  @override
  Duration get position => positionValue;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Stream<Duration> get positionStream => Stream.value(positionValue);
  @override
  Stream<PlayerState> get playerStateStream =>
      Stream.value(PlayerState(isPlaying, ProcessingState.ready));
  @override
  Stream<PlayerException> get errorStream => const Stream.empty();
  @override
  Future<Duration?> setFilePath(
    String path, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async => duration;
  @override
  Future<Duration?> setClip({
    Duration? start,
    Duration? end,
    dynamic tag,
  }) async {
    clips.add((start, end));
    return duration;
  }

  @override
  Future<void> setLoopMode(LoopMode value) async {
    mode = value;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    positionValue = position ?? Duration.zero;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 70)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'quick idea saves standalone, attaches to song, and is accessible from song notes',
    (tester) async {
      await preparePreview(tester);
      sqfliteFfiInit();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('workflow_'),
      ))!;
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: '${root.path}/db.sqlite',
        ),
      ))!;
      final song = SongDocument(title: 'Practice song');
      await tester.runAsync(() => store.save(song));
      await tester.pumpWidget(
        previewHost(MusicHub(store: store, files: AudioFiles(root))),
      );
      await flush(tester);
      await capturePreview(tester, 'workflow-library');
      await tester.tap(find.byTooltip('Quick idea'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note-title')), 'Riff idea');
      await tester.enterText(
        find.byKey(const Key('note-text')),
        '  7h9\nTry slower',
      );
      await tester.tap(find.text('Save'));
      await flush(tester);
      final standalone = (await tester.runAsync(store.notes))!.single;
      expect(standalone.songId, isNull);
      await tester.tap(find.text('Attach to a song'));
      await flush(tester);
      await tester.tap(find.text('Practice song'));
      await flush(tester);
      await tester.tap(find.byTooltip('Back from note'));
      await flush(tester);
      await tester.tap(find.text('Practice song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await flush(tester);
      await tester.tap(find.text('Riff idea'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-text')))
            .controller!
            .text,
        '  7h9\nTry slower',
      );
      await capturePreview(tester, 'workflow-note');
      await tester.tap(find.text('Delete Note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(store.notes))!.length, 1);
      await tester.tap(find.text('Delete Note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await flush(tester);
      expect(await tester.runAsync(store.notes), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    },
  );
  testWidgets('A/B uses native clipping and maps absolute seeks to the clip', (
    tester,
  ) async {
    await preparePreview(tester);
    sqfliteFfiInit();
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('loop_'),
    ))!;
    final store = (await tester.runAsync(
      () => MusicStore.open(
        factory: databaseFactoryFfi,
        location: '${root.path}/db.sqlite',
      ),
    ))!;
    final player = FakePlayback();
    await tester.pumpWidget(
      previewHost(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF276752),
            ),
            scaffoldBackgroundColor: const Color(0xFFF8F6F0),
          ),
          home: PlaybackScreen(
            store: store,
            files: AudioFiles(root),
            recording: const RecordingEntry(
              id: 'recording',
              title: 'Riff',
              relativePath: 'audio/take.m4a',
              durationMs: 10000,
              createdAt: '',
            ),
            player: player,
          ),
        ),
      ),
    );
    await flush(tester);
    tester.widget<RangeSlider>(find.byKey(const Key('loop-range'))).onChanged!(
      const RangeValues(2000, 4000),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Loop A–B'));
    await tester.tap(find.text('Loop A–B'));
    await tester.pumpAndSettle();
    expect(player.clips.last, (
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ));
    expect(player.mode, LoopMode.one);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(3000);
    await tester.pump();
    expect(player.position, const Duration(seconds: 1));
    expect(find.text('Looping 0:02.00 – 0:04.00'), findsOneWidget);
    await capturePreview(tester, 'recording-ab-loop');
    await tester.tap(find.text('Clear A/B'));
    await tester.pumpAndSettle();
    expect(player.clips.last, (null, null));
    expect(player.mode, LoopMode.off);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(player.disposed, true);
    await tester.runAsync(() async {
      await store.close();
      await root.delete(recursive: true);
    });
  });
}
