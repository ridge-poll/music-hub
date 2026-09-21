import 'dart:async';
import 'package:flutter/material.dart';
import 'document.dart';
import 'store.dart';
import 'tab_document.dart';

class TabScreen extends StatefulWidget {
  const TabScreen({super.key, required this.store, required this.song});
  final MusicStore store;
  final SongDocument song;
  @override
  State<TabScreen> createState() => _TabScreenState();
}

class _TabScreenState extends State<TabScreen> with WidgetsBindingObserver {
  TabDocument? tab;
  String? loadError;
  String status = 'Not saved yet';
  final controllers = <String, TextEditingController>{};
  final nodes = <String, FocusNode>{};
  final cellKeys = <String, GlobalKey>{};
  final textScrolls = <String, ScrollController>{};
  final blockScrolls = <ScrollController>[];
  Timer? debounce;
  Future<bool>? pending;
  int generation = 0, savedGeneration = 0;
  int column = 0, row = 0;
  bool leaving = false, exiting = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
  }

  String identity(int c, int r) => '${tab!.positions[c].id}:$r';
  void prepareCells() {
    for (var c = 0; c < tab!.positions.length; c++) {
      for (var r = 0; r < 6; r++) {
        final key = identity(c, r);
        controllers.putIfAbsent(
          key,
          () => TextEditingController(text: tab!.positions[c].cells[r]),
        );
        textScrolls.putIfAbsent(key, () => ScrollController());
        nodes.putIfAbsent(key, () {
          final cellColumn = c, cellRow = r;
          final node = FocusNode();
          node.addListener(() {
            if (!node.hasFocus && textScrolls[key]!.hasClients) {
              textScrolls[key]!.jumpTo(0);
            }
            if (mounted && node.hasFocus) {
              setState(() {
                column = cellColumn;
                row = cellRow;
              });
            }
          });
          return node;
        });
        cellKeys.putIfAbsent(key, () => GlobalKey());
      }
    }
    while (blockScrolls.length < tab!.positions.length ~/ 12) {
      blockScrolls.add(ScrollController());
    }
  }

  Future<void> load() async {
    try {
      final value = await widget.store.loadTab(widget.song.arrangementId);
      if (!mounted) return;
      setState(() {
        tab = value;
        loadError = null;
        prepareCells();
        status = value.revision > 0 ? 'Saved on this device' : 'Not saved yet';
      });
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
    debounce?.cancel();
    if (tab == null) return true;
    if (pending != null) {
      final ok = await pending!;
      if (!ok || !mounted) return false;
      return save();
    }
    if (generation == savedGeneration && tab!.revision > 0) return true;
    final version = generation;
    final snapshot = TabDocument.decode(tab!.encode(), tab!.revision);
    final operation = persist(snapshot, version);
    pending = operation;
    final ok = await operation;
    pending = null;
    if (mounted) setState(() {});
    if (ok && mounted && generation != savedGeneration) return save();
    return ok;
  }

  Future<bool> persist(TabDocument snapshot, int version) async {
    if (mounted) setState(() => status = 'Saving…');
    try {
      final ok = await widget.store.saveTab(snapshot);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(save());
    }
  }

  void focusCell(int c, int r) {
    c = c.clamp(0, tab!.positions.length - 1);
    r = r.clamp(0, 5);
    setState(() {
      column = c;
      row = r;
    });
    final key = identity(c, r);
    // All cells stay mounted so the next field can immediately retain the IME.
    nodes[key]!.requestFocus();
    final context = cellKeys[key]!.currentContext;
    if (context != null) {
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 120),
          alignment: 0.45,
        ),
      );
    }
  }

  void nextCell() {
    if (column + 1 < tab!.positions.length) {
      focusCell(column + 1, row);
    } else if (row < 5) {
      focusCell(0, row + 1);
    }
  }

  void addBlock() {
    final next = tab!.positions.length;
    setState(() {
      tab!.addBlock();
      prepareCells();
    });
    changed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusCell(next, row);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final n in nodes.values) {
      n.dispose();
    }
    for (final s in textScrolls.values) {
      s.dispose();
    }
    for (final s in blockScrolls) {
      s.dispose();
    }
    super.dispose();
  }

  Widget block(int b) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Block ${b + 1} · positions ${b * 12 + 1}–${b * 12 + 12}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const SizedBox(width: 32, height: 24),
                for (var r = 0; r < 6; r++)
                  SizedBox(
                    width: 32,
                    height: 64,
                    child: Center(child: Text('S${r + 1}')),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: blockScrolls[b],
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var c = b * 12; c < (b + 1) * 12; c++)
                          SizedBox(
                            width: 68,
                            height: 24,
                            child: Text(
                              '${c + 1}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                    for (var r = 0; r < 6; r++)
                      Row(
                        children: [
                          for (var c = b * 12; c < (b + 1) * 12; c++)
                            cell(c, r),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget cell(int c, int r) {
    final key = identity(c, r);
    return SizedBox(
      key: cellKeys[key],
      width: 68,
      height: 64,
      child: TextField(
        key: ValueKey('tab-cell-$c-$r'),
        controller: controllers[key],
        focusNode: nodes[key],
        scrollController: textScrolls[key],
        textAlignVertical: TextAlignVertical.top,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        expands: true,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontFamily: 'Courier', fontSize: 16),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(8),
          border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          filled: column == c && row == r,
          fillColor: const Color(0xFFE0EEE6),
        ),
        onTap: () => setState(() {
          column = c;
          row = r;
        }),
        onChanged: (value) {
          tab!.positions[c].cells[r] = value;
          changed();
        },
        onEditingComplete: nextCell,
      ),
    );
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
                        Text(
                          widget.song.title.isEmpty
                              ? 'Untitled song'
                              : widget.song.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'S1 = high string · S6 = low string. Type anything; columns are positions, not beats.',
                          style: TextStyle(fontSize: 12),
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
                    child: SingleChildScrollView(
                      key: const Key('tab-blocks'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var b = 0; b < tab!.positions.length ~/ 12; b++)
                            block(b),
                          OutlinedButton.icon(
                            onPressed: addBlock,
                            icon: const Icon(Icons.add),
                            label: const Text('Add 6-row block'),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  // Keep the toolbar and all its buttons outside keyboard focus traversal.
                  Focus(
                    canRequestFocus: false,
                    descendantsAreFocusable: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          tooltip: 'Previous cell',
                          onPressed: column > 0
                              ? () => focusCell(column - 1, row)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'String above',
                          onPressed: row > 0
                              ? () => focusCell(column, row - 1)
                              : null,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'String below',
                          onPressed: row < 5
                              ? () => focusCell(column, row + 1)
                              : null,
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Next cell',
                          onPressed: nextCell,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        IconButton(
                          tooltip: 'Add block',
                          onPressed: addBlock,
                          icon: const Icon(Icons.add_box_outlined),
                        ),
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
