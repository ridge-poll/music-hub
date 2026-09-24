import 'song_workspace.dart';
import 'metronome_screen.dart';
import 'delete_action.dart';
import 'tuner_screen.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

import 'document.dart';
import 'store.dart';
import 'audio_files.dart';
import 'audio_screen.dart';
import 'sheet_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  Future<(MusicStore, AudioFiles)> open() async {
    final files = AudioFiles(await getApplicationDocumentsDirectory());
    final store = await MusicStore.open(factory: databaseFactory);
    return (store, files);
  }

  late Future<(MusicStore, AudioFiles)> opening = open();
  @override
  Widget build(BuildContext context) => FutureBuilder<(MusicStore, AudioFiles)>(
    future: opening,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return MusicHub(store: snapshot.data!.$1, files: snapshot.data!.$2);
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not open your library. Your files have not been reset.',
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          opening = open();
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

class MusicHub extends StatefulWidget {
  const MusicHub({super.key, required this.store, required this.files});
  final MusicStore store;
  final AudioFiles files;
  @override
  State<MusicHub> createState() => _MusicHubState();
}

class _MusicHubState extends State<MusicHub> {
  bool dark = false;
  @override
  void initState() {
    super.initState();
    unawaited(loadTheme());
  }

  Future<void> loadTheme() async {
    final value = await widget.store.setting('dark_mode');
    if (mounted) setState(() => dark = value == 'true');
  }

  Future<void> setDark(bool value) async {
    await widget.store.setSetting('dark_mode', '$value');
    if (mounted) setState(() => dark = value);
  }

  ThemeData theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF276752),
      brightness: brightness,
    ),
    appBarTheme: const AppBarTheme(centerTitle: false),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Music Hub',
    debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: LibraryScreen(
      store: widget.store,
      files: widget.files,
      dark: dark,
      onDarkChanged: setDark,
    ),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.store,
    required this.files,
    this.dark = false,
    this.onDarkChanged,
  });
  final MusicStore store;
  final AudioFiles files;
  final bool dark;
  final Future<void> Function(bool)? onDarkChanged;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<SongDocument>> songs = widget.store.list();
  String query = '';
  int page = 0, recordingsGeneration = 0;
  void refresh() {
    if (mounted) {
      setState(() {
        songs = widget.store.list();
        recordingsGeneration++;
      });
    }
  }

  Future<void> open(SongDocument song, {String? component}) async {
    await openSong(
      context,
      widget.store,
      widget.files,
      song,
      component: component,
    );
    refresh();
  }

  Future<void> create() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in ['Chords/Lyrics', 'Tab', 'Notes'])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(context, label),
              ),
          ],
        ),
      ),
    );
    if (type != null && mounted) await open(SongDocument(), component: type);
  }

  Future<void> record() async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => RecorderScreen(
          store: widget.store,
          files: widget.files,
          startImmediately: true,
        ),
      ),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(['Songs', 'Recordings', 'Tuner', 'More'][page]),
      actions: [
        if (page == 0)
          TextButton.icon(
            onPressed: create,
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
      ],
    ),
    floatingActionButton: page == 1
        ? FloatingActionButton.extended(
            onPressed: record,
            icon: const Icon(Icons.mic_none),
            label: const Text('Record'),
          )
        : null,
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (index) {
        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TunerScreen(store: widget.store),
            ),
          );
          return;
        }
        setState(() => page = index);
        refresh();
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined),
          label: 'Songs',
        ),
        NavigationDestination(
          icon: Icon(Icons.graphic_eq),
          label: 'Recordings',
        ),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Tuner'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    ),
    body: SafeArea(
      child: page == 1
          ? RecordingsPane(
              key: ValueKey(recordingsGeneration),
              store: widget.store,
              files: widget.files,
            )
          : page == 3
          ? ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Metronome'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MetronomeScreen(store: widget.store),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(
                        store: widget.store,
                        onDarkChanged: widget.onDarkChanged,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search songs',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        setState(() => query = value.toLowerCase()),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<SongDocument>>(
                      future: songs,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: TextButton(
                              onPressed: refresh,
                              child: const Text('Could not load songs. Retry'),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final items = snapshot.data!
                            .where(
                              (song) => '${song.title} ${song.artist}'
                                  .toLowerCase()
                                  .contains(query),
                            )
                            .toList();
                        if (items.isEmpty) {
                          return Center(
                            child: Text(
                              query.isEmpty
                                  ? 'No songs yet'
                                  : 'No matching songs',
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final song = items[index];
                            return SwipeDelete(
                              key: ValueKey(song.id),
                              onDelete: () async {
                                if (await confirmDelete(
                                  context,
                                  'Song',
                                  () => widget.store.deleteSong(song.id),
                                  detail:
                                      'Its documents will be deleted. Recordings remain in Recordings.',
                                )) {
                                  refresh();
                                }
                              },
                              child: Card(
                                margin: EdgeInsets.zero,
                                elevation: 0,
                                child: ListTile(
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                    vertical: -1,
                                  ),
                                  title: Text(
                                    song.title.isEmpty
                                        ? 'Untitled song'
                                        : song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    song.components.join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onTap: () => open(song),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store, this.onDarkChanged});
  final MusicStore store;
  final Future<void> Function(bool)? onDarkChanged;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? dark;
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: Column(
      children: [
        SwitchListTile(
          title: const Text('Dark Mode'),
          value: dark ?? Theme.of(context).brightness == Brightness.dark,
          onChanged: (value) async {
            try {
              if (widget.onDarkChanged != null) {
                await widget.onDarkChanged!(value);
              } else {
                await widget.store.setSetting('dark_mode', '$value');
              }
              if (mounted) {
                setState(() {
                  dark = value;
                  error = null;
                });
              }
            } catch (_) {
              if (mounted) {
                setState(() => error = 'Could not save setting. Try again.');
              }
            }
          },
        ),
        if (error != null) Text(error!),
      ],
    ),
  );
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.store,
    required this.song,
    required this.files,
  });
  final AudioFiles files;
  final MusicStore store;
  final SongDocument song;
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late SongDocument song = widget.song;
  late final TextEditingController title = TextEditingController(
    text: song.title,
  );
  late final TextEditingController artist = TextEditingController(
    text: song.artist,
  );
  late final SheetController sheet = SheetController(text: song.text);
  final UndoHistoryController undo = UndoHistoryController();
  Timer? debounce;
  Future<bool>? pendingSave;
  bool leaving = false, exiting = false;
  bool dirty = false;
  bool conflicted = false;
  int editGeneration = 0;
  String status = 'Not saved yet';
  bool get saving => pendingSave != null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (song.revision > 0) {
      status = 'Saved on this device';
    }
  }

  void changed() {
    setState(() {
      dirty = true;
      editGeneration++;
      status = 'Unsaved changes';
    });
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 800), save);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(save());
    }
  }

  Future<bool> save() async {
    debounce?.cancel();
    if (pendingSave != null) {
      final ok = await pendingSave!;
      if (!ok || !mounted) {
        return false;
      }
      if (dirty) {
        return save();
      }
      return true;
    }
    if (!dirty && song.revision > 0) {
      return true;
    }
    final generation = editGeneration;
    song.title = title.text.trim();
    song.artist = artist.text.trim();
    song.text = sheet.text;
    if (song.revision == 0 && song.isBlank) {
      dirty = false;
      if (mounted) setState(() => status = "Not saved yet");
      return true;
    }
    final snapshot = SongDocument.decode(song.encode(), song.revision);
    final operation = _persist(snapshot, generation);
    pendingSave = operation;
    final ok = await operation;
    pendingSave = null;
    if (mounted) {
      setState(() {});
    }
    if (ok && dirty && mounted) {
      return save();
    }
    return ok;
  }

  Future<bool> _persist(SongDocument snapshot, int generation) async {
    setState(() {
      status = 'Saving…';
    });
    try {
      final ok = await widget.store.save(snapshot);
      if (!mounted) {
        return ok;
      }
      setState(() {
        if (ok) {
          song.revision = snapshot.revision;
          if (generation == editGeneration) {
            dirty = false;
          }
          status = dirty ? 'Unsaved changes' : 'Saved on this device';
        } else {
          conflicted = true;
          status =
              'This song changed elsewhere. Copy your edits before reopening.';
        }
      });
      return ok;
    } catch (_) {
      if (mounted) {
        setState(() {
          status = 'Save failed. Your edits are still here. Tap Save to retry.';
        });
      }
      return false;
    }
  }

  Future<void> leave({bool workspace = false}) async {
    if (exiting) return;
    exiting = true;
    if (!await save() || !mounted) {
      exiting = false;
      return;
    }
    setState(() => leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(workspace ? 'workspace' : null);
  }

  Future<void> perform() async {
    FocusScope.of(context).unfocus();
    if (!await save() || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PerformanceScreen(
          song: SongDocument.decode(song.encode(), song.revision),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    sheet.dispose();
    undo.dispose();
    title.dispose();
    artist.dispose();
    super.dispose();
  }

  Future<void> deleteSong() async {
    debounce?.cancel();
    final pending = pendingSave;
    if (pending != null) await pending;
    if (!mounted) return;
    if (await confirmDelete(
          context,
          'Song',
          () => widget.store.deleteSong(song.id),
          detail:
              'Its documents will be deleted. Recordings remain in Recordings.',
        ) &&
        mounted) {
      setState(() {
        dirty = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    } else if (mounted && dirty) {
      debounce = Timer(
        const Duration(milliseconds: 800),
        () => unawaited(save()),
      );
    }
  }

  Future<void> reload() async {
    try {
      final latest = (await widget.store.list()).firstWhere(
        (s) => s.id == song.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        song = latest;
        title.text = latest.title;
        artist.text = latest.artist;
        sheet.text = latest.text;
        dirty = false;
        conflicted = false;
        status = 'Saved on this device';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          status = 'Could not reopen. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || (!dirty && !saving),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        unawaited(leave());
      }
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to songs',
          icon: const Icon(Icons.arrow_back),
          onPressed: leave,
        ),
        title: const Text('Chords/Lyrics'),
        actions: [
          IconButton(
            tooltip: 'Song workspace',
            onPressed: () => leave(workspace: true),
            icon: const Icon(Icons.folder_open),
          ),
          TextButton(
            onPressed: saving ? null : save,
            child: const Text('Save'),
          ),
          IconButton(
            tooltip: 'Performance mode',
            onPressed: perform,
            icon: const Icon(Icons.play_circle_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    key: const Key('title'),
                    controller: title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Untitled song',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => changed(),
                  ),
                  TextField(
                    controller: artist,
                    decoration: const InputDecoration(
                      hintText: 'Artist (optional)',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (_) => changed(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 13,
                        color: Color(0xFF597064),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            status,
                            key: const Key('save-status'),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<UndoHistoryValue>(
                        valueListenable: undo,
                        builder: (context, value, _) => Row(
                          children: [
                            IconButton(
                              tooltip: 'Undo',
                              onPressed: value.canUndo ? undo.undo : null,
                              icon: const Icon(Icons.undo, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Redo',
                              onPressed: value.canRedo ? undo.redo : null,
                              icon: const Icon(Icons.redo, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (conflicted)
                    TextButton(
                      onPressed: reload,
                      child: const Text('Reopen (discards unsaved edits)'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: PlainSheetEditor(
                  controller: sheet,
                  undoController: undo,
                  onChanged: (_) => changed(),
                ),
              ),
            ),
            if (MediaQuery.viewInsetsOf(context).bottom > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => FocusScope.of(context).unfocus(),
                  child: const Text('Done'),
                ),
              ),
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              TextButton(
                onPressed: saving ? null : deleteSong,
                child: const Text(
                  'Delete Song',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    super.key,
    required this.song,
    this.manageWakeLock = true,
  });
  final SongDocument song;
  final bool manageWakeLock;
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with WidgetsBindingObserver {
  final scroll = ScrollController();
  Timer? timer;
  double size = 26;
  double speed = 24;
  bool playing = false;
  bool wakeFailed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(wake());
  }

  Future<void> wake() async {
    if (!widget.manageWakeLock) {
      return;
    }
    try {
      await WakelockPlus.enable();
    } catch (_) {
      if (mounted) {
        setState(() {
          wakeFailed = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(wake());
    } else {
      timer?.cancel();
      setState(() {
        playing = false;
      });
    }
  }

  void toggle() {
    timer?.cancel();
    setState(() {
      playing = !playing;
    });
    if (!playing) {
      return;
    }
    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!scroll.hasClients) {
        return;
      }
      final next = (scroll.offset + speed / 20).clamp(
        0.0,
        scroll.position.maxScrollExtent,
      );
      scroll.jumpTo(next);
      if (next >= scroll.position.maxScrollExtent) {
        timer?.cancel();
        setState(() {
          playing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.manageWakeLock) {
      unawaited(WakelockPlus.disable().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.song.title.isEmpty ? 'Untitled song' : widget.song.title,
      ),
      actions: [
        IconButton(
          tooltip: 'Smaller text',
          onPressed: size > 18
              ? () => setState(() {
                  size -= 2;
                })
              : null,
          icon: const Icon(Icons.text_decrease),
        ),
        IconButton(
          tooltip: 'Larger text',
          onPressed: size < 42
              ? () => setState(() {
                  size += 2;
                })
              : null,
          icon: const Icon(Icons.text_increase),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
        children: [
          if (widget.song.artist.isNotEmpty)
            Text(
              widget.song.artist,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          if (wakeFailed)
            const Text(
              'Could not keep the screen awake. Check your auto-lock setting.',
            ),
          PerformanceSheet(text: widget.song.text, size: size),
        ],
      ),
    ),
    bottomNavigationBar: SizedBox(
      height: 80 + MediaQuery.paddingOf(context).bottom,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to top',
                onPressed: () => scroll.jumpTo(0),
                icon: const Icon(Icons.vertical_align_top),
              ),
              FilledButton.tonalIcon(
                onPressed: toggle,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                label: Text(playing ? 'Pause' : 'Scroll'),
              ),
              Expanded(
                child: Slider(
                  label: '${speed.round()} px/s',
                  min: 8,
                  max: 60,
                  value: speed,
                  onChanged: (value) => setState(() {
                    speed = value;
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
