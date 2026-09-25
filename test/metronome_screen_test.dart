import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/metronome.dart';
import 'package:music_hub/metronome_audio.dart';
import 'package:music_hub/metronome_screen.dart';
import 'package:music_hub/store.dart';

class FakeClicks implements MetronomeAudio {
  final positionEvents = StreamController<Duration>.broadcast();
  final interruptionEvents = StreamController<void>.broadcast();
  final starts = <MetronomeSettings>[];
  int stops = 0;
  bool disposed = false;
  Completer<void>? pending;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<void> get interruptions => interruptionEvents.stream;
  @override
  Future<void> start(MetronomeSettings settings) async {
    starts.add(settings);
    await pending?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await positionEvents.close();
    await interruptionEvents.close();
  }
}

void main() {
  testWidgets(
    'metronome saves settings, plays, responds to interruption and exits',
    (tester) async {
      sqfliteFfiInit();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: inMemoryDatabasePath,
        ),
      ))!;
      final audio = FakeClicks();
      Future<void> flush() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }

      final screenshotPath = Platform.environment['MUSIC_HUB_SCREENSHOTS'];
      final boundaryKey = GlobalKey();
      if (screenshotPath != null) {
        await tester.runAsync(() async {
          for (final font in {
            'Roboto': '/System/Library/Fonts/SFNS.ttf',
            'MaterialIcons':
                '/Applications/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          }.entries) {
            final loader = FontLoader(font.key);
            loader.addFont(
              File(font.value).readAsBytes().then(ByteData.sublistView),
            );
            await loader.load();
          }
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF276752),
              ),
              scaffoldBackgroundColor: const Color(0xFFF8F6F0),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF8F6F0),
                centerTitle: false,
              ),
            ),
            home: MetronomeScreen(store: store, audio: audio),
          ),
        ),
      );
      await flush();
      expect(find.text('100'), findsOneWidget);
      if (screenshotPath != null) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$screenshotPath/metronome.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.tap(find.byTooltip('Faster'));
      await tester.tap(find.byKey(const Key('beat-1')));
      await flush();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(audio.starts.single.bpm, 101);
      expect(audio.starts.single.accents, [2, 2, 1, 1]);
      audio.positionEvents.add(const Duration(milliseconds: 650));
      await tester.pump();
      expect(find.text('Stop'), findsOneWidget);
      audio.interruptionEvents.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(audio.stops, 1);
      audio.pending = Completer<void>();
      await tester.tap(find.text('Start'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      audio.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(audio.stops, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final rows = (await tester.runAsync(
        () => store.db.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['metronome'],
        ),
      ))!;
      final saved = MetronomeSettings.fromJson(
        jsonDecode(rows.single['value'] as String) as Map<String, dynamic>,
      );
      expect(saved.bpm, 101);
      expect(saved.accents, [2, 2, 1, 1]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(audio.disposed, true);
      final reopened = FakeClicks();
      await tester.pumpWidget(
        MaterialApp(
          home: MetronomeScreen(store: store, audio: reopened),
        ),
      );
      await flush();
      expect(find.text('Listen for BPM'), findsNothing);
      expect(find.text('101'), findsOneWidget);
      expect(reopened.starts, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(store.close);
    },
  );
}
