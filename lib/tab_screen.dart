import 'dart:async';
import 'package:flutter/material.dart';
import 'document.dart';
import 'delete_action.dart';
import 'store.dart';
import 'tab_document.dart';
import 'fixed_tab_editor.dart';

class TabScreen extends StatefulWidget {
  const TabScreen({super.key, required this.store, required this.song});
  final MusicStore store;
  final SongDocument song;
  @override
  State<TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends State<TabScreen> with WidgetsBindingObserver {
  TabDocument? tab;
  late final title = TextEditingController(text: widget.song.title);
  String? loadError;
  String status = 'Not saved yet';
  final controller = TextEditingController();
  final undo = UndoHistoryController();
  bool deleting = false;
  Timer? debounce;
  Future<bool>? pending;
  int generation = 0, savedGeneration = 0;
  bool leaving = false, exiting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final value = await widget.store.loadTab(widget.song.arrangementId);
      if (!mounted) return;
      setState(() {
        tab = value;
        loadError = null;
        controller.text = value.text;
        if (value.migrated) generation++;
        status = value.revision > 0 ? 'Saved on this device' : 'Not saved yet';
      });
      if (value.migrated) unawaited(save());
    } catch (_) {
      if (mounted) {
        setState(
          () => loadError =
              'Could not open this tab. Your saved data has not been changed.',
        );
      }
    }
  }

  void changed() {
    tab!.text = controller.text;
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
    if (tab == null) return true;
    if (pending != null) {
      final ok = await pending!;
      if (!ok || !mounted) return false;
      return save();
    }
    if (generation == savedGeneration) return true;
    final song = SongDocument.decode(widget.song.encode(), widget.song.revision)
      ..title = title.text.trim();
    if (song.revision == 0 && song.isBlank && !tab!.hasContent) {
      savedGeneration = generation;
      if (mounted) setState(() => status = "Not saved yet");
      return true;
    }
    final version = generation;
    final snapshot = TabDocument.decode(tab!.encode(), tab!.revision);
    final operation = persist(snapshot, song, version);
    pending = operation;
    final ok = await operation;
    pending = null;
    if (mounted) setState(() {});
    if (ok && mounted && generation != savedGeneration) return save();
    return ok;
  }

  Future<bool> persist(
    TabDocument snapshot,
    SongDocument song,
    int version,
  ) async {
    if (mounted) setState(() => status = 'Saving…');
    try {
      final ok = snapshot.revision == 0 && !snapshot.hasContent
          ? await widget.store.save(song)
          : await widget.store.saveTab(snapshot, song: song);
      if (ok) {
        widget.song.revision = song.revision;
        widget.song.title = song.title;
      }
      if (mounted) {
        setState(() {
          if (ok) {
            tab!.revision = snapshot.revision;
            savedGeneration = version;
            status = generation == version
                ? 'Saved on this device'
                : 'Unsaved changes';
          } else {
            status =
                'This tab changed or its song was deleted. Your unsaved text is still here.';
          }
        });
      }
      return ok;
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Save failed. Your text is still here. Tap Save to retry.',
        );
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

  void addBlock() {
    final text = controller.text;
    final separator = text.isEmpty || text.endsWith('\n\n')
        ? ''
        : text.endsWith('\n')
        ? '\n'
        : '\n\n';
    controller.value = TextEditingValue(
      text: '$text$separator$blankTabBlock',
      selection: TextSelection.collapsed(
        offset: text.length + separator.length,
      ),
    );
    changed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    title.dispose();
    controller.dispose();
    undo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || tab == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(leave());
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to song',
          onPressed: leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Tab'),
        actions: [
          IconButton(
            tooltip: "Song workspace",
            onPressed: () => leave(workspace: true),
            icon: const Icon(Icons.folder_open),
          ),
          TextButton(
            onPressed: tab == null || pending != null ? null : save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: tab == null
          ? Center(
              child: loadError == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loadError!),
                        TextButton(onPressed: load, child: const Text('Retry')),
                      ],
                    ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('tab-title'),
                          controller: title,
                          decoration: const InputDecoration(
                            hintText: 'Untitled song',
                            border: InputBorder.none,
                          ),
                          onChanged: (_) => changed(),
                        ),
                        Text(
                          status,
                          key: const Key('tab-save-status'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FixedTabEditor(
                      controller: controller,
                      undoController: undo,
                      onChanged: (_) => changed(),
                    ),
                  ),
                  if (tab!.annotations.trim().isNotEmpty)
                    ExpansionTile(
                      title: const Text('Saved annotations'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextFormField(
                            initialValue: tab!.annotations,
                            maxLines: 4,
                            onChanged: (value) {
                              tab!.annotations = value;
                              changed();
                            },
                          ),
                        ),
                      ],
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
                  Focus(
                    canRequestFocus: false,
                    descendantsAreFocusable: false,
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: addBlock,
                          icon: const Icon(Icons.add),
                          label: const Text('Tab Block'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => FocusScope.of(context).unfocus(),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
