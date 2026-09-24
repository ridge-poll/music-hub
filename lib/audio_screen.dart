import 'delete_action.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'audio_files.dart';
import 'document.dart';
import 'recording.dart';
import 'store.dart';
import 'practice_loop.dart';
import 'note.dart';
import 'notes_screen.dart';
import 'main.dart' show EditorScreen;
import 'tab_screen.dart';

class SongRecordingsScreen extends StatefulWidget {
  const SongRecordingsScreen({
    super.key,
    required this.store,
    required this.files,
    required this.song,
  });
  final MusicStore store;
  final AudioFiles files;
  final SongDocument song;
  @override
  State<SongRecordingsScreen> createState() => _SongRecordingsScreenState();
}

class _SongRecordingsScreenState extends State<SongRecordingsScreen> {
  int generation = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.song.title.isEmpty ? 'Song recordings' : widget.song.title,
      ),
    ),
    body: RecordingsPane(
      key: ValueKey(generation),
      store: widget.store,
      files: widget.files,
      songId: widget.song.id,
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => RecorderScreen(
              store: widget.store,
              files: widget.files,
              songId: widget.song.id,
              startImmediately: true,
            ),
          ),
        );
        if (mounted) {
          setState(() {
            generation++;
          });
        }
      },
      icon: const Icon(Icons.mic_none),
      label: const Text('Record for this song'),
    ),
  );
}

class RecordingsPane extends StatefulWidget {
  const RecordingsPane({
    super.key,
    required this.store,
    required this.files,
    this.songId,
  });
  final MusicStore store;
  final AudioFiles files;
  final String? songId;
  @override
  State<RecordingsPane> createState() => _RecordingsPaneState();
}

class _RecordingsPaneState extends State<RecordingsPane> {
  Future<(List<RecordingEntry>, List<AudioDraft>)> load() async => (
    await widget.store.recordings(songId: widget.songId),
    (await widget.files.pending())
        .where((d) => widget.songId == null || d.songId == widget.songId)
        .toList(),
  );
  late Future<(List<RecordingEntry>, List<AudioDraft>)> data = load();
  void refresh() {
    if (mounted) {
      setState(() {
        data = load();
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(List<RecordingEntry>, List<AudioDraft>)>(
    future: data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: refresh,
            child: const Text('Could not load recordings. Retry'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final (takes, drafts) = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Text(
            'Little ideas. Keep them.',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Your recordings stay on this device.'),
          const SizedBox(height: 24),
          for (final draft in drafts)
            Card(
              color: const Color(0xFFFFEBCD),
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.restore),
                title: Text(draft.title),
                subtitle: const Text('Unfinished save · tap to recover'),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => RecorderScreen(
                        store: widget.store,
                        files: widget.files,
                        recovered: draft,
                      ),
                    ),
                  );
                  refresh();
                },
              ),
            ),
          if (takes.isEmpty && drafts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Column(
                children: [
                  Icon(Icons.graphic_eq, size: 56, color: Color(0xFF597064)),
                  SizedBox(height: 16),
                  Text(
                    'A riff, a melody, a first take.',
                    style: TextStyle(fontSize: 19),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap Record. Organize it later.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final take in takes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SwipeDelete(
                key: ValueKey(take.id),
                onDelete: () async {
                  if (await confirmDelete(
                    context,
                    'Recording',
                    () => widget.store.deleteRecording(take.id),
                  )) {
                    refresh();
                  }
                },
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(child: Icon(Icons.play_arrow)),
                    title: Text(take.title),
                    subtitle: Text(
                      '${audioTime(Duration(milliseconds: take.durationMs))} · ${take.songTitle ?? 'Unattached idea'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlaybackScreen(
                            store: widget.store,
                            files: widget.files,
                            recording: take,
                          ),
                        ),
                      );
                      refresh();
                    },
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({
    super.key,
    required this.store,
    required this.files,
    this.songId,
    this.startImmediately = false,
    this.recovered,
  });
  final MusicStore store;
  final AudioFiles files;
  final String? songId;
  final bool startImmediately;
  final AudioDraft? recovered;
  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen>
    with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  final title = TextEditingController();
  final stopwatch = Stopwatch();
  StreamSubscription<RecordState>? stateSubscription;
  StreamSubscription<Amplitude>? meterSubscription;
  Timer? ticker;
  AudioDraft? draft;
  bool capturing = false;
  bool paused = false;
  bool busy = false;
  bool backgrounded = false;
  bool leaving = false;
  double level = 0;
  String? error;
  Duration get elapsed => draft != null && !capturing
      ? Duration(milliseconds: draft!.durationMs)
      : stopwatch.elapsed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    draft = widget.recovered;
    title.text = draft?.title ?? '';
    stateSubscription = recorder.onStateChanged().listen(
      (state) {
        if (!mounted || leaving) {
          return;
        }
        setState(() {
          if (state == RecordState.pause) {
            paused = true;
            stopwatch.stop();
          }
          if (state == RecordState.record) {
            paused = false;
            stopwatch.start();
          }
          if (state == RecordState.stop) {
            stopwatch.stop();
          }
        });
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            error =
                'The microphone was interrupted. Stop to keep the captured audio.';
          });
        }
      },
    );
    ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && capturing) {
        setState(() {});
      }
    });
    if (widget.startImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(start());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    backgrounded =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (backgrounded && capturing && !busy) {
      unawaited(finish());
    }
  }

  Future<void> start() async {
    if (busy || draft != null) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await recorder.hasPermission()) {
        throw StateError(
          'Microphone access is off. Enable it for Music Hub in Settings, then try again.',
        );
      }
      draft = await widget.files.createDraft(songId: widget.songId);
      title.text = draft!.title;
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
          audioInterruption: AudioInterruptionMode.pause,
        ),
        path: widget.files.draftAudio(draft!).path,
      );
      capturing = true;
      paused = false;
      stopwatch.reset();
      stopwatch.start();
      meterSubscription = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amplitude) {
            if (mounted) {
              setState(() {
                level = ((amplitude.current + 60) / 60).clamp(0, 1);
              });
            }
          }, onError: (Object _) {});
      try {
        await WakelockPlus.enable();
      } catch (_) {
        /* Background transition still finalizes capture. */
      }
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : 'Could not start the microphone. You can retry; any capture draft is kept below.';
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
    if (backgrounded && capturing) {
      await finish();
    }
  }

  Future<void> pauseOrResume() async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (paused) {
        await recorder.resume();
      } else {
        await recorder.pause();
      }
    } catch (_) {
      error = 'Could not change recording state. Stop to keep your take.';
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<bool> finish() async {
    if (busy) {
      return false;
    }
    if (!capturing) {
      return true;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final output = await recorder.stop();
      stopwatch.stop();
      capturing = false;
      if (output == null && !await widget.files.draftAudio(draft!).exists()) {
        throw StateError('Recording did not return a file');
      }
      paused = false;
      level = 0;
      draft!.durationMs = stopwatch.elapsedMilliseconds;
      draft!.title = title.text;
      await widget.files.writeDraft(draft!);
      await meterSubscription?.cancel();
      meterSubscription = null;
      return true;
    } catch (_) {
      error =
          'Could not finalize this take. Its draft is kept; retry Stop or reopen it from Recordings.';
      return false;
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (busy || draft == null || !await finish()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final probe = AudioPlayer();
    try {
      // Validate actual media (also detects truncated crash-recovery files).
      final duration = await probe
          .setFilePath(widget.files.draftAudio(draft!).path)
          .timeout(const Duration(seconds: 15));
      if (duration == null || duration == Duration.zero) {
        throw StateError('No playable audio');
      }
      draft!.durationMs = duration.inMilliseconds;
      draft!.title = title.text;
      await widget.files.save(widget.store, draft!);
      if (mounted) {
        setState(() {
          draft = null;
          busy = false;
          leaving = true;
        });
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Could not save this take. The draft is still on this device. Retry, or keep it for later. An interrupted file may not be playable.';
        });
      }
    } finally {
      await probe.dispose();
      if (mounted && !leaving) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> leave() async {
    if (busy) {
      return;
    }
    if (!await finish() || !mounted) {
      return;
    }
    if (draft != null) {
      draft!.title = title.text;
      try {
        await widget.files.writeDraft(draft!);
      } catch (_) {
        if (mounted) {
          setState(() {
            error =
                'Could not update the draft title. The earlier draft remains saved.';
          });
        }
      }
    }
    if (mounted) {
      setState(() {
        leaving = true;
      });
      Navigator.of(context).pop();
    }
  }

  Future<void> discard() async {
    if (busy || draft == null) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this take?'),
        content: const Text(
          'This unfinished recording will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) {
      return;
    }
    if (!await finish()) {
      return;
    }
    setState(() {
      busy = true;
    });
    try {
      await widget.files.discard(draft!);
      if (mounted) {
        setState(() {
          draft = null;
          busy = false;
          leaving = true;
        });
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not discard the draft. Please retry.';
        });
      }
    }
  }

  @override
  void dispose() {
    leaving = true;
    ticker?.cancel();
    unawaited(stateSubscription?.cancel());
    unawaited(meterSubscription?.cancel());
    unawaited(recorder.dispose());
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    title.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || (draft == null && !busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) {
        unawaited(leave());
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Capture an idea'),
        leading: IconButton(
          tooltip: 'Keep draft and return',
          onPressed: busy ? null : leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Text(
              capturing
                  ? (paused ? 'Paused' : 'Listening…')
                  : draft != null
                  ? 'Keep this take.'
                  : 'Make a little music.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              capturing
                  ? (paused
                        ? 'Tap Resume when you are ready.'
                        : 'Recording on this device. Take your time.')
                  : 'A riff, a melody, whatever comes next.',
            ),
            const SizedBox(height: 36),
            Center(
              child: Text(
                audioTime(elapsed),
                style: const TextStyle(fontSize: 60, fontFamily: 'Courier'),
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: capturing && !paused ? level : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            const Text(
              'MIC INPUT LEVEL',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, letterSpacing: 2),
            ),
            const SizedBox(height: 28),
            if (draft != null)
              TextField(
                controller: title,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'Recording name'),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            if (busy)
              const Center(child: CircularProgressIndicator())
            else if (capturing)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: pauseOrResume,
                      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                      label: Text(paused ? 'Resume' : 'Pause'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: finish,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              )
            else if (draft == null)
              FilledButton.icon(
                onPressed: start,
                icon: const Icon(Icons.mic),
                label: const Text('Start recording'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save recording'),
                  ),
                  TextButton(
                    onPressed: leave,
                    child: const Text('Keep draft for later'),
                  ),
                  TextButton(
                    onPressed: discard,
                    child: const Text('Discard take'),
                  ),
                ],
              ),
            const SizedBox(height: 28),
            const Text(
              'Recording pauses for audio interruptions and stops when the app goes into the background.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({
    super.key,
    required this.store,
    required this.files,
    required this.recording,
    this.player,
  });
  final MusicStore store;
  final AudioFiles files;
  final RecordingEntry recording;
  final AudioPlayer? player;
  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen>
    with WidgetsBindingObserver {
  late final player = widget.player ?? AudioPlayer();
  Duration fullDuration = Duration.zero;
  PracticeLoop? activeRegion;
  double regionA = 0, regionB = 0;
  bool changingLoop = false, foreground = true;
  int get absolutePosition =>
      activeRegion?.toAbsolute(player.position.inMilliseconds) ??
      player.position.inMilliseconds;

  bool ready = false;
  bool loop = false;
  String? error;
  late String? attachedTitle = widget.recording.songTitle;
  late String? attachedId = widget.recording.songId;
  StreamSubscription<PlayerException>? errors;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    errors = player.errorStream.listen((event) {
      if (mounted) {
        setState(() {
          error = 'Playback stopped. Try reopening this recording.';
        });
      }
    });
    unawaited(load());
  }

  Future<void> load() async {
    try {
      if (widget.player == null) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      }
      await player.setFilePath(
        widget.files.resolve(widget.recording.relativePath).path,
      );
      if (mounted) {
        setState(() {
          fullDuration =
              player.duration ??
              Duration(milliseconds: widget.recording.durationMs);
          regionB = fullDuration.inMilliseconds.toDouble();
          ready = true;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Could not open this recording. Its library entry has been kept.';
        });
      }
    }
  }

  Future<void> act(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not complete playback. Please retry.';
        });
      }
    }
  }

  Future<void> playOrPause() async {
    if (player.playing && player.processingState != ProcessingState.completed) {
      await act(player.pause);
      return;
    }
    if (player.processingState == ProcessingState.completed) {
      await act(() => player.seek(Duration.zero));
    }
    unawaited(
      act(player.play),
    ); // play completes when playback stops, not when it begins
  }

  Future<void> setRegion(PracticeLoop? region) async {
    if (changingLoop ||
        (region != null && !region.validFor(fullDuration.inMilliseconds))) {
      return;
    }
    final wasPlaying = player.playing;
    setState(() => changingLoop = true);
    try {
      await player.pause();
      await player.setClip(
        start: region == null ? null : Duration(milliseconds: region.startMs),
        end: region == null ? null : Duration(milliseconds: region.endMs),
      );
      await player.setLoopMode(region == null ? LoopMode.off : LoopMode.one);
      await player.seek(Duration.zero);
      if (mounted) {
        setState(() {
          activeRegion = region;
          loop = region != null;
          error = null;
        });
      }
      if (mounted && foreground && wasPlaying) unawaited(act(player.play));
    } catch (_) {
      try {
        await player.setClip();
        await player.setLoopMode(LoopMode.off);
      } catch (_) {}
      if (mounted) {
        setState(() {
          activeRegion = null;
          loop = false;
          error = 'Could not set this loop. Playback is paused; try again.';
        });
      }
    } finally {
      if (mounted) setState(() => changingLoop = false);
    }
  }

  Future<void> openWorkspace({bool tab = false}) async {
    await act(player.pause);
    try {
      final songs = await widget.store.list();
      final song = songs.where((s) => s.id == attachedId).firstOrNull;
      if (song == null || !mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => tab
              ? TabScreen(store: widget.store, song: song)
              : EditorScreen(
                  store: widget.store,
                  song: song,
                  files: widget.files,
                ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not open the song. Try again.');
      }
    }
  }

  Future<void> jotNote() async {
    await act(player.pause);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NoteScreen(
          store: widget.store,
          note: MusicNote(
            title: widget.recording.title,
            text: 'Recording: ${widget.recording.title}\n\n',
            songId: attachedId,
            songTitle: attachedTitle,
          ),
        ),
      ),
    );
  }

  Future<void> attach() async {
    try {
      final songs = await widget.store.list();
      if (!mounted) {
        return;
      }
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Attach to a song')),
              ListTile(
                title: const Text('Unattached idea'),
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final song in songs)
                ListTile(
                  title: Text(
                    song.title.isEmpty ? 'Untitled song' : song.title,
                  ),
                  trailing: song.id == attachedId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, song.id),
                ),
            ],
          ),
        ),
      );
      if (selected == null) {
        return;
      }
      await widget.store.attachRecording(
        widget.recording.id,
        selected.isEmpty ? null : selected,
      );
      if (mounted) {
        setState(() {
          attachedId = selected.isEmpty ? null : selected;
          attachedTitle = selected.isEmpty
              ? null
              : songs.firstWhere((s) => s.id == selected).title;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Could not change the song attachment. Please retry.';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(act(player.pause));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(errors?.cancel());
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Listen back')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0E6),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.graphic_eq,
              size: 48,
              color: Color(0xFF276752),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            widget.recording.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            attachedTitle == null
                ? 'Unattached idea'
                : (attachedTitle!.isEmpty ? 'Untitled song' : attachedTitle!),
          ),
          const SizedBox(height: 28),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!ready && error == null)
            const Center(child: CircularProgressIndicator()),
          if (!ready && error != null)
            TextButton(onPressed: load, child: const Text('Retry')),
          if (ready) ...[
            StreamBuilder<Duration>(
              stream: player.positionStream,
              initialData: player.position,
              builder: (context, snapshot) {
                final duration = fullDuration;
                final relative = snapshot.data ?? Duration.zero;
                final current = Duration(
                  milliseconds:
                      activeRegion?.toAbsolute(relative.inMilliseconds) ??
                      relative.inMilliseconds,
                );
                final max = duration.inMilliseconds.toDouble();
                return Column(
                  children: [
                    Slider(
                      value: current.inMilliseconds.toDouble().clamp(
                        0,
                        max > 0 ? max : 1,
                      ),
                      max: max > 0 ? max : 1,
                      onChanged: max > 0 && !changingLoop
                          ? (value) => unawaited(
                              act(
                                () => player.seek(
                                  Duration(
                                    milliseconds:
                                        activeRegion?.toRelative(
                                          value.round(),
                                        ) ??
                                        value.round(),
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(audioTime(current)),
                        Text(audioTime(duration)),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (fullDuration.inMilliseconds >= 200) ...[
              const Text('A/B practice loop'),
              RangeSlider(
                key: const Key('loop-range'),
                values: RangeValues(regionA, regionB),
                min: 0,
                max: fullDuration.inMilliseconds.toDouble(),
                labels: RangeLabels(
                  preciseTime(regionA.round()),
                  preciseTime(regionB.round()),
                ),
                onChanged: changingLoop
                    ? null
                    : (range) => setState(() {
                        regionA = range.start;
                        regionB = range.end;
                      }),
              ),
              Text(
                'A ${preciseTime(regionA.round())}   ·   B ${preciseTime(regionB.round())}',
                textAlign: TextAlign.center,
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: changingLoop
                        ? null
                        : () => setState(() {
                            regionA = absolutePosition.toDouble().clamp(
                              0,
                              regionB,
                            );
                          }),
                    child: const Text('Set A here'),
                  ),
                  TextButton(
                    onPressed: changingLoop
                        ? null
                        : () => setState(() {
                            regionB = absolutePosition.toDouble().clamp(
                              regionA,
                              fullDuration.inMilliseconds.toDouble(),
                            );
                          }),
                    child: const Text('Set B here'),
                  ),
                  FilledButton.tonal(
                    onPressed: changingLoop || regionB - regionA < 200
                        ? null
                        : () => setRegion(
                            PracticeLoop(regionA.round(), regionB.round()),
                          ),
                    child: const Text('Loop A–B'),
                  ),
                  if (activeRegion != null)
                    TextButton(
                      onPressed: changingLoop ? null : () => setRegion(null),
                      child: const Text('Clear A/B'),
                    ),
                ],
              ),
              if (activeRegion != null)
                Text(
                  'Looping ${preciseTime(activeRegion!.startMs)} – ${preciseTime(activeRegion!.endMs)}',
                  textAlign: TextAlign.center,
                ),
            ],
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final playing =
                    (snapshot.data?.playing ?? false) &&
                    snapshot.data?.processingState != ProcessingState.completed;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Back 10 seconds',
                      onPressed: changingLoop
                          ? null
                          : () => unawaited(
                              act(
                                () => player.seek(
                                  Duration(
                                    milliseconds:
                                        (player.position.inMilliseconds - 10000)
                                            .clamp(0, 1 << 40),
                                  ),
                                ),
                              ),
                            ),
                      icon: const Icon(Icons.replay_10),
                    ),
                    const SizedBox(width: 20),
                    FilledButton(
                      onPressed: changingLoop ? null : playOrPause,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        shape: const CircleBorder(),
                      ),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      tooltip: 'Loop recording',
                      isSelected: loop && activeRegion == null,
                      onPressed: changingLoop || activeRegion != null
                          ? null
                          : () => unawaited(
                              act(() async {
                                await player.setLoopMode(
                                  loop ? LoopMode.off : LoopMode.one,
                                );
                                if (mounted) {
                                  setState(() {
                                    loop = !loop;
                                  });
                                }
                              }),
                            ),
                      icon: const Icon(Icons.repeat),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: jotNote,
                icon: const Icon(Icons.edit_note),
                label: const Text('Jot a note'),
              ),
              if (attachedId != null) ...[
                TextButton(
                  onPressed: openWorkspace,
                  child: const Text('Open song'),
                ),
                TextButton(
                  onPressed: () => openWorkspace(tab: true),
                  child: const Text('Work on tab'),
                ),
              ],
            ],
          ),
          OutlinedButton.icon(
            onPressed: attach,
            icon: const Icon(Icons.link),
            label: const Text('Attach to a song'),
          ),
          TextButton(
            onPressed: () async {
              if (await confirmDelete(context, 'Recording', () async {
                    await player.stop();
                    await widget.store.deleteRecording(widget.recording.id);
                  }) &&
                  context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'Delete Recording',
              style: TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Original audio · saved locally',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
