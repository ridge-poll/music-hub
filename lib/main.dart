import 'tab_lab.dart';
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

class MusicHub extends StatelessWidget {
  const MusicHub({super.key, required this.store, required this.files});
  final MusicStore store;
  final AudioFiles files;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Music Hub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF276752),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F6F0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8F6F0),
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: LibraryScreen(store: store, files: files),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.store, required this.files});
  final MusicStore store;
  final AudioFiles files;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<SongDocument>> songs = widget.store.list();
  String query = '';
  int page = 0;
  int recordingsGeneration = 0;
  void refresh() {
    if (mounted) {
      setState(() {
        songs = widget.store.list();
        recordingsGeneration++;
      });
    }
  }

  Future<void> open(SongDocument song) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EditorScreen(store: widget.store, song: song, files: widget.files),
      ),
    );
    refresh();
  }

  Future<void> record() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecorderScreen(
          store: widget.store,
          files: widget.files,
          startImmediately: true,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        page = 1;
      });
    }
    refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Music Hub',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => open(SongDocument()),
          icon: const Icon(Icons.add),
          label: const Text('New song'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      elevation: 0,
      onPressed: record,
      backgroundColor: const Color(0xFF276752),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.mic_none_rounded),
      label: const Text('Record'),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (index) {
        if (index == 3) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const TabLabScreen()));
          return;
        }
        if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TunerScreen(store: widget.store),
            ),
          );
          return;
        }
        setState(() {
          page = index;
        });
        refresh();
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music),
          label: 'Songs',
        ),
        NavigationDestination(
          icon: Icon(Icons.graphic_eq),
          label: 'Recordings',
        ),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Tuner'),
        NavigationDestination(
          icon: Icon(Icons.science_outlined),
          label: 'Tab lab',
        ),
      ],
    ),
    body: SafeArea(
      child: page == 1
          ? RecordingsPane(
              key: ValueKey(recordingsGeneration),
              store: widget.store,
              files: widget.files,
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR MUSIC, WITHIN REACH',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Color(0xFF597064),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick up where you left off.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Find a song or artist',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      query = value.toLowerCase();
                    }),
                  ),
                  const SizedBox(height: 20),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notes_rounded,
                                  size: 48,
                                  color: Color(0xFF597064),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  query.isEmpty
                                      ? 'Every song starts somewhere.'
                                      : 'No matching songs.',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                if (query.isEmpty)
                                  const Text(
                                    'Paste your lyrics, or record a little idea.',
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 10),
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
                                      'Recordings will remain in your library.',
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
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF0E6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.music_note_outlined,
                                    ),
                                  ),
                                  title: Text(
                                    song.title.isEmpty
                                        ? 'Untitled song'
                                        : song.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      song.artist.isNotEmpty
                                          ? song.artist
                                          : (song.text.trim().isEmpty
                                                ? 'Ready for an idea'
                                                : song.text.split('\n').first),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
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

  Future<void> leave() async {
    final ok = await save();
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
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

  Future<void> recordForSong() async {
    FocusScope.of(context).unfocus();
    if (!await save() || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongRecordingsScreen(
          store: widget.store,
          files: widget.files,
          song: song,
        ),
      ),
    );
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
          detail: 'Recordings will remain in your library.',
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
    canPop: !dirty && !saving,
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
        title: const Text('Song'),
        actions: [
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
                color: Colors.white,
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
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: recordForSong,
                      icon: const Icon(Icons.graphic_eq),
                      label: const Text('Recordings'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: perform,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                  ],
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
