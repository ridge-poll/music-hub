import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_hub/circle.dart';
import 'package:music_hub/circle_audio.dart';

class TestPlayer extends Fake implements AudioPlayer {
  // Like a native player, this object must never cross an isolate boundary.
  final port = ReceivePort();
  final files = <String>[];
  int plays = 0;
  Completer<void>? loadGate, loadStarted;
  @override
  Future<Duration?> setFilePath(
    String path, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    expect(await File(path).length(), greaterThan(44));
    files.add(path);
    loadStarted?.complete();
    await loadGate?.future;
    return const Duration(milliseconds: 1800);
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    port.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (_) async => null,
        );
  });
  test(
    'native transport renders in an isolate, loads WAV and replays from cache',
    () async {
      final player = TestPlayer();
      final audio = NativeCircleAudio(player: player);
      addTearDown(audio.dispose);
      await audio.play(const CircleChord(0));
      await audio.play(const CircleChord(0));
      expect(player.plays, 2);
      expect(player.files.length, 2);
      expect(player.files[0], player.files[1]);
    },
  );
  test(
    'Stop during source preparation prevents late playback and allows retry',
    () async {
      final player = TestPlayer()
        ..loadGate = Completer<void>()
        ..loadStarted = Completer<void>();
      final audio = NativeCircleAudio(player: player);
      addTearDown(audio.dispose);
      final playing = audio.play(const CircleChord(1, minor: true));
      await player.loadStarted!.future;
      final stopping = audio.stop();
      player.loadGate!.complete();
      await playing;
      await stopping;
      expect(player.plays, 0);
      player.loadGate = null;
      player.loadStarted = null;
      await audio.play(const CircleChord(1, minor: true));
      expect(player.plays, 1);
    },
  );
}
