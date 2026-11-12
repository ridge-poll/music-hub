import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'circle.dart';

abstract class CircleAudio {
  Future<void> play(CircleChord chord);
  Future<void> stop();
  Future<void> dispose();
}

class NativeCircleAudio implements CircleAudio {
  final player = AudioPlayer(handleInterruptions: false);
  final subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> tail = Future.value();
  Directory? directory;
  int generation = 0;
  bool disposed = false, configured = false;
  Future<void> queue(Future<void> Function() action) {
    final next = tail.then((_) => action());
    tail = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> play(CircleChord chord) {
    final token = ++generation;
    return queue(() async {
      if (disposed || token != generation) return;
      final session = await AudioSession.instance;
      if (!configured) {
        await session.configure(const AudioSessionConfiguration.music());
        subscriptions.add(
          session.interruptionEventStream.listen((event) {
            if (event.begin) unawaited(stop().catchError((Object _) {}));
          }),
        );
        subscriptions.add(
          session.becomingNoisyEventStream.listen(
            (_) => unawaited(stop().catchError((Object _) {})),
          ),
        );
        configured = true;
      }
      directory ??= await Directory.systemTemp.createTemp('music_hub_circle_');
      final file = File('${directory!.path}/${chord.root}-${chord.minor}.wav');
      if (!await file.exists()) {
        final bytes = await Isolate.run(() => renderCircleChord(chord));
        if (disposed || token != generation) return;
        await file.writeAsBytes(bytes);
      }
      if (disposed || token != generation) return;
      await player.setFilePath(file.path);
      if (disposed || token != generation) return;
      if (!await session.setActive(true)) {
        throw StateError('Audio session unavailable');
      }
      if (disposed || token != generation) return;
      unawaited(player.play().catchError((Object _) {}));
    });
  }

  @override
  Future<void> stop() {
    generation++;
    return queue(() async {
      if (!disposed) await player.stop();
    });
  }

  @override
  Future<void> dispose() {
    disposed = true;
    generation++;
    return queue(() async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await player.dispose();
      if (directory != null) await directory!.delete(recursive: true);
    });
  }
}
