import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'metronome.dart';

Future<List<int>> _render(MetronomeSettings settings) =>
    Isolate.run(() => renderMetronome(settings));

abstract class MetronomeAudio {
  Stream<Duration> get positions;
  Stream<void> get interruptions;
  Future<void> start(MetronomeSettings settings);
  Future<void> stop();
  Future<void> dispose();
}

class NativeMetronomeAudio implements MetronomeAudio {
  final _player = AudioPlayer(handleInterruptions: false);
  final _interruptions = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Directory? _directory;
  int _generation = 0;
  Future<void> _tail = Future.value();
  bool _disposed = false, _configured = false;
  @override
  Stream<Duration> get positions => _player.createPositionStream(
    minPeriod: const Duration(milliseconds: 30),
    maxPeriod: const Duration(milliseconds: 60),
  );
  @override
  Stream<void> get interruptions => _interruptions.stream;

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.catchError((Object _) {});
    return next;
  }

  void _interrupt() {
    if (_disposed) return;
    _interruptions.add(null);
    unawaited(stop().catchError((Object _) {}));
  }

  @override
  Future<void> start(MetronomeSettings settings) {
    final generation = ++_generation;
    return _enqueue(() async {
      if (_disposed || generation != _generation) return;
      final session = await AudioSession.instance;
      if (!_configured) {
        await session.configure(const AudioSessionConfiguration.music());
        _subscriptions.add(
          session.interruptionEventStream.listen((event) {
            if (event.begin) _interrupt();
          }),
        );
        _subscriptions.add(
          session.becomingNoisyEventStream.listen((_) => _interrupt()),
        );
        _subscriptions.add(_player.errorStream.listen((_) => _interrupt()));
        _configured = true;
      }
      await _player.stop();
      final bytes = await _render(settings);
      if (_disposed || generation != _generation) return;
      _directory ??= await Directory.systemTemp.createTemp('music_hub_click_');
      final file = File('${_directory!.path}/$generation.wav');
      await file.writeAsBytes(bytes, flush: true);
      await _player.setFilePath(file.path);
      await _player.setLoopMode(LoopMode.one);
      for (final previous in _directory!.listSync().whereType<File>()) {
        if (previous.path != file.path) await previous.delete();
      }
      if (_disposed || generation != _generation) return;
      if (!await session.setActive(true)) {
        throw StateError('Audio session unavailable');
      }
      if (_disposed || generation != _generation) return;
      unawaited(_player.play().catchError((Object _) => _interrupt()));
    });
  }

  @override
  Future<void> stop() {
    _generation++;
    return _enqueue(() async {
      if (!_disposed) await _player.stop();
    });
  }

  @override
  Future<void> dispose() {
    _disposed = true;
    _generation++;
    return _enqueue(() async {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      await _player.dispose();
      await _interruptions.close();
      if (_directory != null) await _directory!.delete(recursive: true);
    });
  }
}
