import 'dart:async';
import 'package:flutter/material.dart';
import 'delete_action.dart';
import 'document.dart';
import 'note.dart';
import 'store.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.store, this.song});
  final MusicStore store;
  final SongDocument? song;
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<List<MusicNote>> notes = widget.store.notes(
    songId: widget.song?.id,
  );
  void refresh() {
    if (mounted) {
      setState(() {
        notes = widget.store.notes(songId: widget.song?.id);
      });
    }
  }

  Future<void> open(MusicNote note) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NoteScreen(store: widget.store, note: note),
      ),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.song == null
            ? 'Notes & ideas'
            : '${widget.song!.title.isEmpty ? 'Song' : widget.song!.title} · Notes',
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => open(
        MusicNote(songId: widget.song?.id, songTitle: widget.song?.title),
      ),
      icon: const Icon(Icons.edit_note),
      label: const Text('New note'),
    ),
    body: FutureBuilder<List<MusicNote>>(
      future: notes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: refresh,
              child: const Text('Could not load notes. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Text('A riff idea, a reminder, a few words.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            for (final note in snapshot.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SwipeDelete(
                  onDelete: () async {
                    if (await confirmDelete(
                      context,
                      'Note',
                      () => widget.store.deleteNote(note.id),
                      detail: 'This note will be removed from your library.',
                    )) {
                      refresh();
                    }
                  },
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => open(note),
                      title: Text(
                        note.title.isEmpty ? 'Untitled idea' : note.title,
                      ),
                      subtitle: Text(
                        note.text.isEmpty
                            ? note.songTitle ?? 'Unattached idea'
                            : note.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key, required this.store, required this.note});
  final MusicStore store;
  final MusicNote note;
  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> with WidgetsBindingObserver {
  late final title = TextEditingController(text: widget.note.title);
  late final text = TextEditingController(text: widget.note.text);
  Timer? debounce;
  Future<bool>? pending;
  int generation = 0, saved = -1;
  bool leaving = false, exiting = false, deleting = false;
  String status = 'Not saved yet';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.note.revision > 0) {
      saved = 0;
      status = 'Saved on this device';
    }
  }

  void changed() {
    setState(() {
      generation++;
      status = 'Unsaved changes';
    });
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(save()),
    );
  }

  Future<bool> save() async {
    if (deleting) return true;
    debounce?.cancel();
    if (pending != null) {
      if (!await pending!) return false;
      return save();
    }
    if (saved == generation) return true;
    final version = generation;
    final snapshot = MusicNote(
      id: widget.note.id,
      title: title.text,
      text: text.text,
      revision: widget.note.revision,
      songId: widget.note.songId,
    );
    final operation = persist(snapshot, version);
    pending = operation;
    final ok = await operation;
    pending = null;
    if (ok && mounted && saved != generation) return save();
    return ok;
  }

  Future<bool> persist(MusicNote snapshot, int version) async {
    try {
      final ok = await widget.store.saveNote(snapshot);
      if (mounted) {
        setState(() {
          if (ok) {
            widget.note.revision = snapshot.revision;
            saved = version;
            status = version == generation
                ? 'Saved on this device'
                : 'Unsaved changes';
          } else {
            status =
                'This note changed or was deleted. Your unsaved text is still here.';
          }
        });
      }
      return ok;
    } catch (_) {
      if (mounted) setState(() => status = 'Save failed. Tap Save to retry.');
      return false;
    }
  }

  Future<void> leave() async {
    if (exiting) return;
    exiting = true;
    if (!await save() || !mounted) {
      exiting = false;
      return;
    }
    setState(() => leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> attach() async {
    if (!await save() || !mounted) return;
    try {
      final songs = await widget.store.list();
      if (!mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Unattached idea'),
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final song in songs)
                ListTile(
                  title: Text(
                    song.title.isEmpty ? 'Untitled song' : song.title,
                  ),
                  onTap: () => Navigator.pop(context, song.id),
                ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      await widget.store.attachNote(
        widget.note.id,
        selected.isEmpty ? null : selected,
      );
      if (mounted) {
        setState(() {
          widget.note.songId = selected.isEmpty ? null : selected;
          widget.note.songTitle = selected.isEmpty
              ? null
              : songs.firstWhere((s) => s.id == selected).title;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = 'Could not change attachment. Try again.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    title.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(leave());
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back from note',
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Note'),
        actions: [TextButton(onPressed: save, child: const Text('Save'))],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('note-title'),
                    controller: title,
                    decoration: const InputDecoration(hintText: 'Idea title'),
                    onChanged: (_) => changed(),
                  ),
                  Text(status, style: const TextStyle(fontSize: 12)),
                  TextButton.icon(
                    onPressed: attach,
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(widget.note.songTitle ?? 'Attach to a song'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TextField(
                key: const Key('note-text'),
                autofocus: widget.note.revision == 0,
                controller: text,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Write anything…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
                onChanged: (_) => changed(),
              ),
            ),
            if (MediaQuery.viewInsetsOf(context).bottom > 0)
              TextButton(
                onPressed: () => FocusScope.of(context).unfocus(),
                child: const Text('Done'),
              )
            else
              TextButton(
                onPressed: () async {
                  deleting = true;
                  debounce?.cancel();
                  await pending;
                  if (!context.mounted) return;
                  if (await confirmDelete(
                        context,
                        'Note',
                        () => widget.store.deleteNote(widget.note.id),
                        detail: 'This note will be removed from your library.',
                      ) &&
                      mounted) {
                    setState(() => leaving = true);
                    await WidgetsBinding.instance.endOfFrame;
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    deleting = false;
                    if (mounted && saved != generation) unawaited(save());
                  }
                },
                child: const Text(
                  'Delete Note',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
