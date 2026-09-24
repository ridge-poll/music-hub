import 'dart:async';
import 'package:flutter/material.dart';
import 'document.dart';
import 'delete_action.dart';
import 'note.dart';
import 'store.dart';

class SongNotesScreen extends StatefulWidget {
  const SongNotesScreen({super.key, required this.store, required this.song});
  final MusicStore store;
  final SongDocument song;
  @override
  State<SongNotesScreen> createState() => _SongNotesScreenState();
}

class _SongNotesScreenState extends State<SongNotesScreen>
    with WidgetsBindingObserver {
  late final title = TextEditingController(text: widget.song.title);
  final text = TextEditingController();
  MusicNote? note;
  bool deleting = false;
  Timer? debounce;
  Future<bool>? pending;
  int generation = 0, saved = 0;
  bool leaving = false, exiting = false;
  String status = '';
  String? loadError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final value = await widget.store.songNote(widget.song);
      if (mounted) {
        setState(() {
          note = value;
          text.text = value.text;
          loadError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadError = 'Could not open notes.');
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
    if (note == null || saved == generation) return true;
    final song = SongDocument.decode(widget.song.encode(), widget.song.revision)
      ..title = title.text.trim();
    if (song.revision == 0 && song.isBlank && text.text.trim().isEmpty) {
      saved = generation;
      if (mounted) setState(() => status = "Not saved yet");
      return true;
    }
    final version = generation;
    final snapshot = MusicNote(
      id: note!.id,
      text: text.text,
      revision: note!.revision,
      songId: song.id,
    );
    final operation = persist(snapshot, song, version);
    pending = operation;
    final ok = await operation;
    pending = null;
    if (ok && mounted && saved != generation) return save();
    return ok;
  }

  Future<bool> persist(
    MusicNote snapshot,
    SongDocument song,
    int version,
  ) async {
    try {
      // A title-only edit can create a Song without an empty child document.
      final ok = snapshot.revision == 0 && snapshot.text.trim().isEmpty
          ? await widget.store.save(song)
          : await widget.store.saveNote(snapshot, song: song);
      if (ok) {
        widget.song.revision = song.revision;
        widget.song.title = song.title;
        note!.revision = snapshot.revision;
        saved = version;
      }
      if (mounted) {
        setState(
          () => status = ok
              ? 'Saved on this device'
              : 'This song changed. Your unsaved text is still here.',
        );
      }
      return ok;
    } catch (_) {
      if (mounted) setState(() => status = 'Save failed. Tap Save to retry.');
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
    if (mounted) Navigator.pop(context, workspace ? 'workspace' : null);
  }

  Future<void> deleteSong() async {
    deleting = true;
    debounce?.cancel();
    await pending;
    if (!mounted) return;
    if (await confirmDelete(
      context,
      'Song',
      () => widget.store.deleteSong(widget.song.id),
      detail: 'Its documents will be deleted. Recordings remain in Recordings.',
    )) {
      if (!mounted) return;
      setState(() => leaving = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } else {
      deleting = false;
      if (mounted) unawaited(save());
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
          tooltip: 'Back from notes',
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Notes'),
        actions: [
          IconButton(
            tooltip: 'Song workspace',
            onPressed: () => leave(workspace: true),
            icon: const Icon(Icons.folder_open),
          ),
          TextButton(onPressed: save, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        child: note == null
            ? Center(
                child: loadError == null
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: load,
                        child: Text('$loadError Retry'),
                      ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      key: const Key('note-title'),
                      controller: title,
                      decoration: const InputDecoration(
                        hintText: 'Untitled song',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => changed(),
                    ),
                  ),
                  if (status.isNotEmpty)
                    Text(status, style: Theme.of(context).textTheme.labelSmall),
                  const Divider(height: 1),
                  Expanded(
                    child: TextField(
                      key: const Key('note-text'),
                      controller: text,
                      expands: true,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Notes',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(20),
                      ),
                      onChanged: (_) => changed(),
                    ),
                  ),
                  if (widget.song.revision > 0 &&
                      MediaQuery.viewInsetsOf(context).bottom == 0)
                    TextButton(
                      onPressed: deleteSong,
                      child: Text(
                        'Delete Song',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (MediaQuery.viewInsetsOf(context).bottom > 0)
                    TextButton(
                      onPressed: () => FocusScope.of(context).unfocus(),
                      child: const Text('Done'),
                    ),
                ],
              ),
      ),
    ),
  );
}
