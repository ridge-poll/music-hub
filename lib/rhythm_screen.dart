import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'metronome.dart' show TapTempo;
import 'rhythm.dart';
import 'rhythm_audio.dart';
import 'store.dart';

class RhythmScreen extends StatefulWidget {
  const RhythmScreen({super.key, required this.store, this.audio});
  final MusicStore store;
  final RhythmAudio? audio;
  @override
  State<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends State<RhythmScreen>
    with WidgetsBindingObserver {
  late final audio = widget.audio ?? NativeRhythmAudio();
  final taps = TapTempo(), clock = Stopwatch()..start();
  final subscriptions = <StreamSubscription<dynamic>>[];
  final undo = <RhythmPattern>[], redo = <RhythmPattern>[];
  RhythmPattern pattern = RhythmPattern();
  int? selectedRow, bpmPreview;
  List<int> selectedPath = [];
  final focus = <String, List<int>>{};
  RhythmRow? preview;
  bool ready = false,
      loadFailed = false,
      saveFailed = false,
      running = false,
      loading = false,
      allowPop = false,
      leaving = false,
      foreground = true;
  double progress = 0;
  int generation = 0, writeGeneration = 0;
  String? message;
  Future<void> writes = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscriptions.add(
      audio.positions.listen((position) {
        if (!mounted || !running || loading) return;
        final frames = rhythmCycleFrames(pattern);
        setState(
          () => progress =
              (position.inMicroseconds * rhythmSampleRate / 1000000 % frames) /
              frames,
        );
      }),
    );
    subscriptions.add(
      audio.interruptions.listen(
        (_) => unawaited(stop('Audio interrupted. Tap Play to resume.')),
      ),
    );
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final value = await widget.store.setting('rhythm');
      final loaded = value == null
          ? RhythmPattern()
          : RhythmPattern.fromJson(jsonDecode(value));
      if (mounted) {
        setState(() {
          pattern = loaded;
          ready = true;
          loadFailed = false;
          message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loadFailed = true;
          message =
              'Could not read the saved rhythm. Retry to keep your existing pattern safe.';
        });
      }
    }
  }

  void persist() {
    final token = ++writeGeneration, value = jsonEncode(pattern.toJson());
    writes = writes.then((_) async {
      try {
        await widget.store.setSetting('rhythm', value);
        if (mounted && token == writeGeneration) {
          setState(() => saveFailed = false);
        }
      } catch (_) {
        if (mounted && token == writeGeneration) {
          setState(() => saveFailed = true);
        }
      }
    });
  }

  void change(RhythmPattern next, {bool history = true}) {
    if (jsonEncode(next.toJson()) == jsonEncode(pattern.toJson())) return;
    if (history) {
      undo.add(pattern);
      if (undo.length > 40) undo.removeAt(0);
      redo.clear();
    }
    setState(() {
      pattern = next;
      preview = null;
      message = null;
      progress = 0;
    });
    persist();
    if (running) unawaited(start());
  }

  void history(bool backwards) {
    final from = backwards ? undo : redo, to = backwards ? redo : undo;
    if (from.isEmpty) return;
    to.add(pattern);
    final next = from.removeLast();
    setState(() {
      selectedRow = null;
      selectedPath = [];
      focus.clear();
    });
    change(next, history: false);
  }

  Future<void> start() async {
    if (!foreground || !ready) return;
    final token = ++generation;
    setState(() {
      running = true;
      loading = true;
      progress = 0;
      message = null;
    });
    try {
      await audio.start(pattern);
      if (mounted && token == generation) setState(() => loading = false);
    } catch (_) {
      if (mounted && token == generation) {
        await stop('Could not play rhythm. Tap Play to retry.');
      }
    }
  }

  Future<void> stop([String? reason]) async {
    generation++;
    if (mounted) {
      setState(() {
        running = false;
        loading = false;
        progress = 0;
        message = reason;
      });
    }
    try {
      await audio.stop();
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Could not stop audio. Leave this screen to release playback.',
        );
      }
    }
  }

  Future<void> leave() async {
    if (leaving) return;
    leaving = true;
    await writes;
    if (saveFailed) {
      persist();
      await writes;
    }
    if (!mounted) return;
    if (saveFailed) {
      setState(() => leaving = false);
      return;
    }
    await stop();
    if (!mounted) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    generation++;
    for (final s in subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(audio.dispose().catchError((Object _) {}));
    clock.stop();
    super.dispose();
  }

  void select(int row, List<int> path, {bool hit = false}) {
    setState(() {
      selectedRow = row;
      selectedPath = path;
    });
    if (hit) change(pattern.replaceRow(row, pattern.rows[row].cycleHit(path)));
  }

  Future<void> divide() async {
    if (selectedRow == null) return;
    final index = selectedRow!,
        row = pattern.rows[index],
        path = List<int>.of(selectedPath);
    try {
      setState(() => preview = row.divide(path, 4));
    } on FormatException {
      /* Show the limit in the sheet. */
    }
    final count = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DivideSheet(
        row: row,
        path: path,
        onPreview: (row) {
          if (mounted) setState(() => preview = row);
        },
      ),
    );
    if (!mounted) return;
    setState(() => preview = null);
    if (count == null || count == 1) return;
    try {
      final next = row.divide(path, count);
      // Nested subdivisions can be tiny in the whole-cycle overview. Keep the
      // chosen branch editable at phone width; Whole cycle returns to context.
      if (path.isNotEmpty) focus[row.id] = path;
      selectedPath = [...path, 0];
      change(pattern.replaceRow(index, next));
    } on FormatException catch (e) {
      setState(() => message = e.message);
    }
  }

  void merge() {
    if (selectedRow == null || selectedPath.isEmpty) return;
    final index = selectedRow!, row = pattern.rows[index];
    final next = row.merge(selectedPath);
    selectedPath = selectedPath.sublist(0, selectedPath.length - 1);
    focus.remove(row.id);
    change(pattern.replaceRow(index, next));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(leave());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Rhythm'),
        actions: [
          IconButton(
            tooltip: 'Undo',
            onPressed: undo.isEmpty ? null : () => history(true),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: redo.isEmpty ? null : () => history(false),
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      body: !ready
          ? Center(
              child: loadFailed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(message!),
                        ),
                        TextButton(onPressed: load, child: const Text('Retry')),
                      ],
                    )
                  : const CircularProgressIndicator(),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Slower',
                        onPressed: pattern.bpm > 40
                            ? () => change(pattern.copy(bpm: pattern.bpm - 1))
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        '${bpmPreview ?? pattern.bpm} BPM',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        tooltip: 'Faster',
                        onPressed: pattern.bpm < 240
                            ? () => change(pattern.copy(bpm: pattern.bpm + 1))
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                      TextButton(
                        onPressed: () {
                          final bpm = taps.tap(clock.elapsedMilliseconds);
                          if (bpm != null) change(pattern.copy(bpm: bpm));
                        },
                        child: const Text('Tap tempo'),
                      ),
                    ],
                  ),
                  Slider(
                    min: 40,
                    max: 240,
                    divisions: 200,
                    label: '${bpmPreview ?? pattern.bpm} BPM',
                    value: (bpmPreview ?? pattern.bpm).toDouble(),
                    onChanged: (value) =>
                        setState(() => bpmPreview = value.round()),
                    onChangeEnd: (value) {
                      bpmPreview = null;
                      change(pattern.copy(bpm: value.round()));
                    },
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Pulses per cycle'),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: pattern.pulses,
                        items: [
                          for (var n = 1; n <= 16; n++)
                            DropdownMenuItem(value: n, child: Text('$n')),
                        ],
                        onChanged: (n) {
                          if (n != null) change(pattern.copy(pulses: n));
                        },
                      ),
                    ],
                  ),
                  if (saveFailed)
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Rhythm not saved. Your edits are still here.',
                          ),
                        ),
                        TextButton(
                          onPressed: persist,
                          child: const Text('Retry save'),
                        ),
                      ],
                    ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(message!),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '· rest   ○ hit   ● accent\nTap to cycle. Hold to select.',
                    ),
                  ),
                  for (var index = 0; index < pattern.rows.length; index++)
                    buildRow(index),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: pattern.rows.length < rhythmMaxRows
                          ? () {
                              change(
                                pattern.copy(
                                  rows: [...pattern.rows, RhythmRow()],
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add row'),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: !ready
                ? null
                : running
                ? () => stop()
                : start,
            icon: Icon(running ? Icons.stop : Icons.play_arrow),
            label: Text(
              running ? (loading ? 'Stop (preparing…)' : 'Stop') : 'Play',
            ),
          ),
        ),
      ),
    ),
  );
  Widget buildRow(int index) {
    final actual = pattern.rows[index],
        row = selectedRow == index && preview != null ? preview! : actual;
    final branch = focus[row.id] ?? <int>[];
    final root = row.root.at(branch);
    final span = branchSpan(row.root, branch);
    final localProgress = running
        ? (progress - span.$1.value) / span.$2.value
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              DropdownButton<RhythmSound>(
                key: ValueKey('sound-$index'),
                value: row.sound,
                items: [
                  for (final sound in RhythmSound.values)
                    DropdownMenuItem(value: sound, child: Text(sound.label)),
                ],
                onChanged: (sound) {
                  if (sound != null) {
                    change(
                      pattern.replaceRow(index, actual.copy(sound: sound)),
                    );
                  }
                },
              ),
              if (branch.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => focus.remove(row.id)),
                  child: const Text('Whole cycle'),
                ),
              IconButton(
                tooltip: 'Remove row ${index + 1}',
                onPressed: () {
                  final rows = pattern.rows.toList()..removeAt(index);
                  selectedRow = null;
                  focus.remove(row.id);
                  change(pattern.copy(rows: rows));
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (branch.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Focused block'),
            ),
          RhythmBlocks(
            root: root,
            pathPrefix: branch,
            selected: selectedRow == index ? selectedPath : null,
            progress: localProgress,
            key: ValueKey('rhythm-row-$index'),
            onTap: (path) => select(index, path, hit: true),
            onHold: (path) => select(index, path),
          ),
          if (selectedRow == index)
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: divide, child: const Text('Divide')),
                Tooltip(
                  message:
                      'Merge siblings, keeping the first hit. Undo restores the group.',
                  child: TextButton(
                    onPressed: selectedPath.isEmpty ? null : merge,
                    child: const Text('Merge'),
                  ),
                ),
                if (selectedPath.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        setState(() => focus[row.id] = List.of(selectedPath)),
                    child: const Text('Focus block'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

(CycleFraction, CycleFraction) branchSpan(RhythmBlock root, List<int> path) {
  var start = CycleFraction.of(0), duration = CycleFraction.of(1), block = root;
  for (final index in path) {
    duration = duration.divide(block.children.length);
    for (var i = 0; i < index; i++) {
      start = start + duration;
    }
    block = block.children[index];
  }
  return (start, duration);
}

class RhythmBlocks extends StatelessWidget {
  const RhythmBlocks({
    super.key,
    required this.root,
    this.pathPrefix = const [],
    this.selected,
    this.progress,
    this.onTap,
    this.onHold,
  });
  final RhythmBlock root;
  final List<int> pathPrefix;
  final List<int>? selected;
  final double? progress;
  final ValueChanged<List<int>>? onTap, onHold;
  @override
  Widget build(BuildContext context) {
    final leaves = rhythmLeaves(root), colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var i = 0; i < leaves.length; i++)
              Builder(
                builder: (context) {
                  final leaf = leaves[i], path = [...pathPrefix, ...leaf.path];
                  final active =
                      selected != null && selected!.join(',') == path.join(',');
                  return Positioned(
                    left: leaf.start.value * box.maxWidth,
                    width: leaf.duration.value * box.maxWidth,
                    top: 0,
                    bottom: 0,
                    child: Semantics(
                      button: true,
                      selected: active,
                      label:
                          'Block ${i + 1}, ${['rest', 'hit', 'accent'][leaf.hit]}',
                      child: Material(
                        color: leaf.hit == 2
                            ? colors.primary
                            : leaf.hit == 1
                            ? colors.primaryContainer
                            : colors.surfaceContainerHighest,
                        child: InkWell(
                          onTap: onTap == null ? null : () => onTap!(path),
                          onLongPress: onHold == null
                              ? null
                              : () => onHold!(path),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: active
                                    ? colors.tertiary
                                    : colors.outlineVariant,
                                width: active ? 2 : 0.5,
                              ),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: Text(
                                    ['·', '○', '●'][leaf.hit],
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: leaf.hit == 2
                                          ? colors.onPrimary
                                          : colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (progress != null && progress! >= 0 && progress! < 1)
              Positioned(
                left: (progress! * box.maxWidth).clamp(0, box.maxWidth - 2),
                top: 0,
                bottom: 0,
                width: 2,
                child: IgnorePointer(
                  child: ColoredBox(color: colors.onSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DivideSheet extends StatefulWidget {
  const DivideSheet({
    super.key,
    required this.row,
    required this.path,
    required this.onPreview,
  });
  final RhythmRow row;
  final List<int> path;
  final ValueChanged<RhythmRow?> onPreview;
  @override
  State<DivideSheet> createState() => _DivideSheetState();
}

class _DivideSheetState extends State<DivideSheet> {
  final controller = FixedExtentScrollController(initialItem: 3);
  int count = 4;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  RhythmRow? candidate() {
    try {
      return widget.row.divide(widget.path, count);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = candidate();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Divide into', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (next != null) RhythmBlocks(root: next.root.at(widget.path)),
            if (next == null)
              const Text('Subdivision limit reached for this row.'),
            SizedBox(
              height: 150,
              child: CupertinoPicker(
                scrollController: controller,
                itemExtent: 36,
                onSelectedItemChanged: (i) {
                  setState(() => count = i + 1);
                  widget.onPreview(candidate());
                },
                children: [
                  for (var n = 1; n <= 16; n++)
                    Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: next == null
                      ? null
                      : () => Navigator.pop(context, count),
                  child: const Text('Divide'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
