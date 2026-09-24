import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/audio_screen.dart';
import 'package:music_hub/notes_screen.dart';
import 'package:music_hub/tab_screen.dart';
import 'package:music_hub/song_workspace.dart';
import 'package:music_hub/playback_timeline.dart';
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
    'lazy creation, direct notes routing, workspace and persisted dark mode',
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
      await tester.pumpWidget(
        previewHost(MusicHub(store: store, files: AudioFiles(root))),
      );
      await flush(tester);
      for (final type in ['Chords/Lyrics', 'Tab', 'Notes']) {
        await tester.tap(find.text('New'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(type));
        await flush(tester);
        // An untouched editor, even after enough time for autosave, creates nothing.
        await tester.pump(const Duration(seconds: 2));
        if (type != 'Tab') {
          await tester.enterText(
            find.byKey(Key(type == 'Notes' ? 'note-text' : 'sheet-text')),
            '  \n',
          );
          await tester.pump(const Duration(seconds: 2));
        }

        await tester.tap(find.byIcon(Icons.arrow_back));
        await flush(tester);
        expect(await tester.runAsync(store.list), isEmpty);
      }
      expect(
        (await tester.runAsync(() => store.db.query('tab_documents')))!,
        isEmpty,
      );
      expect((await tester.runAsync(store.notes))!, isEmpty);
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await flush(tester);
      await tester.enterText(find.byKey(const Key('note-title')), 'Riff idea');
      await tester.enterText(
        find.byKey(const Key('note-text')),
        '  7h9\nTry slower',
      );
      await tester.tap(find.text('Save'));
      await flush(tester);
      final original = (await tester.runAsync(store.list))!.single;
      expect(original.hasNotes, true);
      expect(original.text, isEmpty);
      expect((await tester.runAsync(store.notes))!.single.songId, original.id);
      await tester.tap(find.byTooltip('Back from notes'));
      await flush(tester);
      await capturePreview(tester, 'workflow-library');
      await tester.tap(find.text('Riff idea'));
      await flush(tester);
      expect(find.byType(SongNotesScreen), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-text')))
            .controller!
            .text,
        '  7h9\nTry slower',
      );
      await capturePreview(tester, 'workflow-note');
      await tester.tap(find.byTooltip('Song workspace'));
      await flush(tester);
      expect(find.byType(SongWorkspaceScreen), findsOneWidget);
      expect(
        (await tester.runAsync(store.list))!.single.lastEdited,
        original.lastEdited,
      );
      await tester.tap(find.text('Chords/Lyrics'));
      await flush(tester);
      await tester.enterText(
        find.byKey(const Key('sheet-text')),
        '{Am} On the porch',
      );
      await tester.tap(find.byTooltip('Back to songs'));
      await flush(tester);
      await tester.pageBack();
      await flush(tester);
      await tester.tap(find.text('Riff idea'));
      await flush(tester);
      expect(find.byType(SongWorkspaceScreen), findsOneWidget);
      expect(find.byType(EditorScreen), findsNothing);
      await capturePreview(tester, 'song-workspace');
      await tester.pageBack();
      await flush(tester);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Metronome'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await flush(tester);
      expect(await tester.runAsync(() => store.setting('dark_mode')), 'true');
      expect(
        Theme.of(tester.element(find.byType(SwitchListTile))).brightness,
        Brightness.dark,
      );
      await capturePreview(tester, 'settings-dark');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        previewHost(MusicHub(store: store, files: AudioFiles(root))),
      );
      await flush(tester);
      expect(
        Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    },
  );
  testWidgets(
    'tab-only Song is created lazily and opens directly; add recording from Song',
    (tester) async {
      await preparePreview(tester);
      sqfliteFfiInit();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('song_tab_'),
      ))!;
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: '${root.path}/db.sqlite',
        ),
      ))!;
      await tester.pumpWidget(MusicHub(store: store, files: AudioFiles(root)));
      await flush(tester);
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab'));
      await flush(tester);
      await tester.tap(find.text('Tab Block'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await flush(tester);
      expect(await tester.runAsync(store.list), isEmpty);
      final field = find.byKey(const Key('tab-text'));
      final controller = tester.widget<TextField>(field).controller!;
      await tester.tap(field);
      controller.selection = const TextSelection.collapsed(offset: 4);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: controller.text.replaceRange(4, 4, '7h9'),
          selection: const TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await flush(tester);
      final song = (await tester.runAsync(store.list))!.single;
      expect(song.components, ['Tab']);
      await tester.tap(find.byTooltip('Back to song'));
      await flush(tester);
      await tester.tap(find.text('Untitled song'));
      await flush(tester);
      expect(find.byType(TabScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Song workspace'));
      await flush(tester);
      await tester.runAsync(
        () => store.saveRecording(
          id: 'take',
          title: 'Evening take',
          hash: 'hash',
          relativePath: 'audio.m4a',
          durationMs: 1000,
          createdAt: '',
        ),
      );
      await tester.tap(find.text('Recordings'));
      await flush(tester);
      await tester.tap(find.byTooltip('Add recording'));
      await flush(tester);
      await tester.tap(find.text('Evening take'));
      await flush(tester);
      expect((await tester.runAsync(store.recordings))!.single.songId, song.id);
      expect((await tester.runAsync(store.list))!.single.recordingCount, 1);
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
    final timeline = find.byKey(const Key('playback-timeline'));
    final bounds = tester.getRect(timeline);
    final left = bounds.left + 16,
        right = bounds.right - 16,
        width = right - left,
        y = bounds.center.dy;
    // Drag the real handles, not callback-only mocks.
    await tester.dragFrom(Offset(left, y), Offset(width * .2, 0));
    await tester.pumpAndSettle();
    await tester.dragFrom(Offset(right, y), Offset(-width * .6, 0));
    await tester.pumpAndSettle();
    expect(player.clips.last.$1!.inMilliseconds, closeTo(2000, 30));
    expect(player.clips.last.$2!.inMilliseconds, closeTo(4000, 30));
    expect(player.mode, LoopMode.one);
    await tester.tapAt(Offset(left + width * .3, y));
    await tester.pump();
    expect(player.position.inMilliseconds, closeTo(1000, 40));
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(RangeSlider), findsNothing);
    await capturePreview(tester, 'recording-ab-loop');
    final current = tester.widget<PlaybackTimeline>(
      find.byType(PlaybackTimeline),
    );
    await tester.dragFrom(
      Offset(left + width * current.region!.startMs / 10000, y),
      Offset(-width, 0),
    );
    await tester.pumpAndSettle();
    final end = tester
        .widget<PlaybackTimeline>(find.byType(PlaybackTimeline))
        .region!
        .endMs;
    await tester.dragFrom(
      Offset(left + width * end / 10000, y),
      Offset(width, 0),
    );
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
