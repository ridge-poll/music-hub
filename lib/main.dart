import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

import 'document.dart';
import 'store.dart';

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
  late Future<MusicStore> opening = MusicStore.open(factory: databaseFactory);
  @override
  Widget build(BuildContext context) => FutureBuilder<MusicStore>(
    future: opening,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return MusicHub(store: snapshot.data!);
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
                          opening = MusicStore.open(factory: databaseFactory);
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
  const MusicHub({super.key, required this.store});
  final MusicStore store;
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
    home: LibraryScreen(store: store),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.store});
  final MusicStore store;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<SongDocument>> songs = widget.store.list();
  String query = '';
  Future<void> open(SongDocument song) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(store: widget.store, song: song),
      ),
    );
    if (mounted) {
      setState(() {
        songs = widget.store.list();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Music Hub')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => open(SongDocument()),
      icon: const Icon(Icons.add),
      label: const Text('New song'),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your songs',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'A place to write. A space to play.\nSaved on this device · works offline',
              ),
            ),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search title or artist',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() {
                query = value.toLowerCase();
              }),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<SongDocument>>(
                future: songs,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          songs = widget.store.list();
                        }),
                        child: const Text('Could not load songs. Retry'),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!
                      .where(
                        (s) => '${s.title} ${s.artist}'.toLowerCase().contains(
                          query,
                        ),
                      )
                      .toList();
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        query.isEmpty
                            ? 'Start with a few words and a chord.\nTap New song to begin.'
                            : 'No matching songs.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final song = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.music_note_outlined),
                        ),
                        title: Text(
                          song.title.isEmpty ? 'Untitled song' : song.title,
                        ),
                        subtitle: Text(
                          song.artist.isEmpty ? 'Chords & lyrics' : song.artist,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => open(song),
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
  const EditorScreen({super.key, required this.store, required this.song});
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
              'Conflicting edit saved in History. Reopen the song to continue.';
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

  Future<void> history() async {
    List<SavedVersion> versions;
    try {
      versions = await widget.store.history(song.sheetId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load History. Please retry.'),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final chosen = await showModalBottomSheet<SavedVersion>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text('Saved versions'),
              subtitle: Text('Recover any version as a new song.'),
            ),
            Expanded(
              child: versions.isEmpty
                  ? const Center(child: Text('No saved versions yet.'))
                  : ListView.builder(
                      itemCount: versions.length,
                      itemBuilder: (_, i) {
                        final v = versions[i];
                        final doc = SongDocument.decode(v.content, v.revision);
                        return ListTile(
                          title: Text(
                            'Version ${v.revision}${v.conflict ? ' · recovered conflict' : ''}',
                          ),
                          subtitle: Text(
                            doc.title.isEmpty ? 'Untitled song' : doc.title,
                          ),
                          trailing: const Icon(Icons.restore),
                          onTap: () => Navigator.pop(context, v),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }
    final old = SongDocument.decode(chosen.content, chosen.revision);
    final copy = SongDocument(
      title: '${old.title} (recovered)',
      artist: old.artist,
      lines: old.lines
          .map(
            (l) => LyricLine(
              lyric: l.lyric,
              chords: l.chords.map((c) => Chord(c.offset, c.name)).toList(),
            ),
          )
          .toList(),
    );
    try {
      await widget.store.save(copy);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recovered as a separate song in your library.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recovery could not be saved. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    title.dispose();
    artist.dispose();
    super.dispose();
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
          IconButton(
            tooltip: 'Saved versions',
            onPressed: history,
            icon: const Icon(Icons.history),
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              key: const Key('title'),
              controller: title,
              decoration: const InputDecoration(labelText: 'Song title'),
              onChanged: (_) => changed(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artist,
              decoration: const InputDecoration(labelText: 'Artist (optional)'),
              onChanged: (_) => changed(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  key: const Key('save-status'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (conflicted)
              TextButton(
                onPressed: () async {
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
                      dirty = false;
                      conflicted = false;
                      status = 'Saved on this device';
                    });
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        status =
                            'Could not reopen. Retry or recover from History.';
                      });
                    }
                  }
                },
                child: const Text('Reopen saved song'),
              ),
            Text(
              'Chords & lyrics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Type a lyric line. Place the cursor, then tap + Chord. Tap a chord to edit it.',
              ),
            ),
            for (var i = 0; i < song.lines.length; i++)
              LyricLineEditor(
                key: ValueKey(song.lines[i].id),
                line: song.lines[i],
                number: i + 1,
                onChanged: changed,
                onDelete: () async {
                  final index = i;
                  final remove = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove this line?'),
                      content: const Text(
                        'The line and its chords will be removed. Saved versions remain in History.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (remove == true && mounted) {
                    setState(() {
                      song.lines.removeAt(index);
                      if (song.lines.isEmpty) {
                        song.lines.add(LyricLine());
                      }
                    });
                    changed();
                  }
                },
              ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  song.lines.add(LyricLine());
                });
                changed();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add lyric line'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: perform,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Performance mode'),
            ),
            TextButton.icon(
              onPressed: () async {
                if (!await save()) {
                  return;
                }
                await Clipboard.setData(
                  ClipboardData(text: exportChordPro(song)),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ChordPro copied to clipboard.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy as ChordPro'),
            ),
          ],
        ),
      ),
    ),
  );
}

class LyricLineEditor extends StatefulWidget {
  const LyricLineEditor({
    super.key,
    required this.line,
    required this.number,
    required this.onChanged,
    required this.onDelete,
  });
  final LyricLine line;
  final int number;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  @override
  State<LyricLineEditor> createState() => _LyricLineEditorState();
}

class _LyricLineEditorState extends State<LyricLineEditor> {
  late final TextEditingController controller = TextEditingController(
    text: widget.line.lyric,
  );
  @override
  void didUpdateWidget(covariant LyricLineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line != widget.line) {
      controller.text = widget.line.lyric;
    }
  }

  Future<void> chord([Chord? existing]) async {
    final offset =
        existing?.offset ??
        (controller.selection.isValid
            ? controller.selection.baseOffset
            : controller.text.length);
    final input = TextEditingController(text: existing?.name ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add chord at cursor' : 'Edit chord'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 24,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\[\]{}\n\r]')),
          ],
          decoration: const InputDecoration(hintText: 'Am, C/G, F♯m7…'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    // Dialog route disposes its text field after the closing animation.
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (value == null || !mounted) {
      return;
    }
    setState(() {
      if (existing != null) {
        widget.line.chords.remove(existing);
      }
      if (value.trim().isNotEmpty) {
        widget.line.chords.add(
          Chord(offset.clamp(0, widget.line.lyric.length), value.trim()),
        );
      }
    });
    widget.onChanged();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LINE ${widget.number}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: chord,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Chord'),
              ),
              IconButton(
                tooltip: 'Remove line ${widget.number}',
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          if (widget.line.chords.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChordLineView(line: widget.line, size: 17, onChord: chord),
            ),
          TextField(
            key: ValueKey('lyric-${widget.number}'),
            controller: controller,
            minLines: 1,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Write a lyric…',
              isDense: true,
            ),
            onChanged: (text) {
              setState(() {
                widget.line.edit(text);
              });
              widget.onChanged();
            },
          ),
        ],
      ),
    ),
  );
}

// Render lyric fragments and their chord labels in the same wrap cell so
// labels remain anchored as font size and available width change.
class ChordLineView extends StatelessWidget {
  const ChordLineView({
    super.key,
    required this.line,
    this.size = 24,
    this.onChord,
  });
  final LyricLine line;
  final double size;
  final void Function(Chord)? onChord;
  @override
  Widget build(BuildContext context) {
    final boundaries = <int>{
      0,
      line.lyric.length,
      ...line.chords.map((c) => c.offset),
    };
    for (final match in RegExp(r'\s+').allMatches(line.lyric)) {
      boundaries.add(match.end);
    }
    final positions = boundaries.toList()..sort();
    if (line.lyric.isEmpty && line.chords.isEmpty) {
      return SizedBox(height: size);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.start,
      runSpacing: 8,
      children: [
        for (var i = 0; i < positions.length; i++)
          if (i < positions.length - 1 ||
              line.chords.any((c) => c.offset == positions[i]))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: size * 1.8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in line.chords.where(
                        (c) => c.offset == positions[i],
                      ))
                        Semantics(
                          button: onChord != null,
                          label: 'Chord ${c.name}',
                          child: InkWell(
                            onTap: onChord == null ? null : () => onChord!(c),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                c.name,
                                style: TextStyle(
                                  fontSize: size * 0.8,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  i + 1 < positions.length
                      ? line.lyric.substring(positions[i], positions[i + 1])
                      : '',
                  style: TextStyle(fontSize: size, height: 1.35),
                ),
              ],
            ),
      ],
    );
  }
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
          for (final line in widget.song.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ChordLineView(line: line, size: size),
            ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
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
  );
}
