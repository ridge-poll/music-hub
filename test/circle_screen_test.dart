import 'preview_support.dart';
import 'dart:io';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/store.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_hub/circle.dart';
import 'package:music_hub/circle_audio.dart';
import 'package:music_hub/circle_screen.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/main.dart';

class FakeChordAudio implements CircleAudio {
  final played = <CircleChord>[];
  int stops = 0;
  bool disposed = false;
  @override
  Future<void> play(CircleChord chord) async {
    played.add(chord);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class ThemeStore extends Fake implements MusicStore {
  @override
  Future<List<SongDocument>> list() async => [];
}

void main() {
  testWidgets(
    'loaded theme applies on the first library frame without a fade',
    (tester) async {
      for (final dark in [true, false]) {
        await tester.pumpWidget(
          MusicHub(
            key: ValueKey(dark),
            store: ThemeStore(),
            files: AudioFiles(Directory.systemTemp),
            initialDark: dark,
          ),
        );
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.themeMode, dark ? ThemeMode.dark : ThemeMode.light);
        expect(app.themeAnimationDuration, Duration.zero);
        expect(
          Theme.of(tester.element(find.byType(LibraryScreen))).brightness,
          dark ? Brightness.dark : Brightness.light,
        );
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'tap, continuous clockwise and reverse scrubbing, minor and lifecycle',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = FakeChordAudio();
      await tester.pumpWidget(MaterialApp(home: CircleScreen(audio: audio)));
      final wheel = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CirclePainter,
      );
      final rect = tester.getRect(wheel), center = tester.getCenter(wheel);
      Offset point(double angle, double fraction) =>
          center +
          Offset(math.sin(angle), -math.cos(angle)) *
              (rect.width / 2 * fraction);
      final gesture = await tester.startGesture(point(0, .85));
      for (var i = 1; i <= 24; i++) {
        await gesture.moveTo(point(i * math.pi / 6, .85));
        await tester.pump();
      }
      expect(audio.played.last.register, 'C6');
      for (var i = 23; i >= 0; i--) {
        await gesture.moveTo(point(i * math.pi / 6, .85));
        await tester.pump();
      }
      await gesture.up();
      expect(audio.played.last.register, 'C4');
      await tester.tapAt(point(0, .5));
      await tester.pump();
      expect(audio.played.last.name, 'Am');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(audio.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      expect(audio.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fixed centered wheel has no dropdown or vertical scroll at phone sizes',
    (tester) async {
      await preparePreview(tester);
      for (final size in [
        const Size(390, 844),
        const Size(320, 568),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          previewHost(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF276752),
                  brightness: Brightness.dark,
                ),
              ),
              home: CircleScreen(audio: FakeChordAudio()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final wheel = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CirclePainter,
        );
        final area = find.byWidgetPredicate((w) => w is LayoutBuilder);
        final rect = tester.getRect(wheel);
        expect(
          tester.getCenter(wheel).dy,
          closeTo(tester.getCenter(area).dy, 1),
        );
        expect(find.byType(Scrollable), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.text('Chord names'), findsNothing);
        expect(
          rect.bottom,
          lessThan(tester.getRect(find.byTooltip('Play selected chord')).top),
        );
        expect(tester.takeException(), isNull);
        if (size.width == 390) await capturePreview(tester, 'circle-centered');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets('auto-scroll yields to held touch and resumes on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceScreen(
          song: SongDocument(
            title: 'Long',
            text: List.filled(300, 'A line of lyrics').join('\n'),
          ),
          manageWakeLock: false,
        ),
      ),
    );
    await tester.tap(find.text('Scroll'));
    await tester.pump(const Duration(seconds: 1));
    final list = find.byType(ListView);
    final controller = tester.widget<ListView>(list).controller!;
    expect(controller.offset, greaterThan(0));
    final gesture = await tester.startGesture(tester.getCenter(list));
    final held = controller.offset;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, held);
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.offset, greaterThan(held + 30));
    final moved = controller.offset;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, moved);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.offset, greaterThan(moved));
    await tester.pumpWidget(const SizedBox());
  });
}
