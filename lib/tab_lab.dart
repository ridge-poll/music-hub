import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tab_lab_model.dart';

enum TabVariant { fretboard, fretFirst, activeString, wheel }

const variantNames = [
  'A · Fretboard',
  'B1 · Fret first',
  'B2 · Active string',
  'C · Thumbwheel',
];

class TabLabScreen extends StatefulWidget {
  const TabLabScreen({super.key});
  @override
  State<TabLabScreen> createState() => _TabLabScreenState();
}

class _TabLabScreenState extends State<TabLabScreen> {
  final List<Map<String, Object?>> results = [];
  int order = 0;
  Future<void> run(TabVariant variant, bool correction, bool practice) async {
    final result = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute(
        builder: (_) => TabTrialScreen(
          variant: variant,
          correction: correction,
          practice: practice,
        ),
      ),
    );
    if (result != null && mounted) setState(() => results.add(result));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tab entry lab')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Stage 4 · Try the interactions',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'These are disposable experiments. Nothing becomes a saved song or a real tab document. Practice each variant, then run both tasks. Results last only while this lab is open; copy them before leaving.',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => order = (order + 1) % 4),
          child: Text(
            'Rotate trial order · starting ${variantNames[order].split(' · ').first}',
          ),
        ),
        for (var n = 0; n < 4; n++)
          Builder(
            builder: (context) {
              final variant = TabVariant.values[(n + order) % 4];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variantNames[variant.index],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        [
                          'Tap a string/fret intersection.',
                          'Choose a fret, then tap a string for each note.',
                          'Select a string once, then tap frets repeatedly.',
                          'Select a string; swipe the wheel to a fret, then place it.',
                        ][variant.index],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => run(variant, false, true),
                            child: const Text('Practice'),
                          ),
                          TextButton(
                            onPressed: () => run(variant, false, false),
                            child: const Text('Create riff'),
                          ),
                          TextButton(
                            onPressed: () => run(variant, true, false),
                            child: const Text('Fix 10 errors'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        Text(
          'Session results (${results.length})',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const Text(
          'Compare creation and correction separately. Gaze shifts and frustration are self-reported, not inferred.',
        ),
        for (final result in results)
          ListTile(
            title: Text('${result['variant']} · ${result['task']}'),
            subtitle: Text(
              '${result['seconds']} s · ${result['taps']} taps · ${result['undos']} undo · ${result['remainingErrors']} remaining note differences',
            ),
          ),
        OutlinedButton.icon(
          onPressed: results.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: const JsonEncoder.withIndent('  ').convert(results),
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Results copied. Paste into a note to keep them.',
                        ),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.copy),
          label: const Text('Copy session results'),
        ),
      ],
    ),
  );
}

class TabTrialScreen extends StatefulWidget {
  const TabTrialScreen({
    super.key,
    required this.variant,
    required this.correction,
    required this.practice,
  });
  final TabVariant variant;
  final bool correction, practice;
  @override
  State<TabTrialScreen> createState() => _TabTrialScreenState();
}

class _TabTrialScreenState extends State<TabTrialScreen>
    with WidgetsBindingObserver {
  late final doc = TabLabDocument(correction: widget.correction)
    ..advance = !widget.correction;
  final clock = Stopwatch();
  Timer? ticker;
  bool started = false, paused = false, finishing = false;
  int taps = 0, gestures = 0, undos = 0, checks = 0, interruptions = 0;
  int? armedFret;
  int wheelFret = 0;
  (int, int)? moving;
  final Map<int, Offset> pointers = {};
  final Set<int> dragged = {};
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    clock.stop();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        started &&
        !paused &&
        !finishing) {
      clock.stop();
      setState(() {
        paused = true;
        interruptions++;
      });
    }
  }

  void start() {
    setState(() {
      started = true;
      clock.start();
    });
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void followCursor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          (doc.position * 48.0 - 96).clamp(0, scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void put(int fret, int string) {
    setState(() {
      doc.put(fret, onString: string);
      moving = null;
    });
    followCursor();
  }

  void selectCell(int position, int string) {
    setState(() {
      if (moving != null) {
        if (doc.columns[position].containsKey(string) &&
            (position, string) != moving) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choose an empty destination for this move.'),
            ),
          );
          return;
        }
        doc.move(moving!.$1, moving!.$2, position, string);
        moving = null;
      }
      doc.position = position;
      doc.string = string;
    });
  }

  void selectString(int string) {
    setState(() => doc.string = string);
    if (widget.variant == TabVariant.fretFirst && armedFret != null) {
      put(armedFret!, string);
      setState(() => armedFret = null);
    }
  }

  Future<void> finish() async {
    clock.stop();
    setState(() => finishing = true);
    final remaining = tabDifferences(doc.columns, referenceRiff());
    final feedback = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _TrialFeedback(remaining: remaining, practice: widget.practice),
    );
    if (!mounted) return;
    if (feedback == null) {
      setState(() => finishing = false);
      if (!paused) clock.start();
      return;
    }
    Navigator.pop(context, <String, Object?>{
      'variant': variantNames[widget.variant.index],
      'task': widget.practice
          ? 'Practice'
          : widget.correction
          ? 'Correction'
          : 'Creation',
      'seconds': (clock.elapsedMilliseconds / 1000).toStringAsFixed(1),
      'taps': taps,
      'swipes': gestures,
      'undos': undos,
      'checks': checks,
      'interruptions': interruptions,
      'remainingErrors': remaining,
      ...feedback,
    });
  }

  Widget stringButtons() => Wrap(
    spacing: 4,
    children: [
      for (var s = 6; s >= 1; s--)
        ChoiceChip(
          key: ValueKey('trial-string-$s'),
          label: Text('$s ${['E', 'B', 'G', 'D', 'A', 'E'][s - 1]}'),
          selected: doc.string == s,
          onSelected: (_) => selectString(s),
        ),
    ],
  );
  Widget keypad() => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (var fret = 0; fret <= 12; fret++)
        SizedBox(
          width: 48,
          height: 44,
          child: OutlinedButton(
            key: ValueKey('fret-key-$fret'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: armedFret == fret
                  ? const Color(0xFFD0E7DC)
                  : null,
            ),
            onPressed: () => widget.variant == TabVariant.fretFirst
                ? setState(() => armedFret = fret)
                : put(fret, doc.string),
            child: Text('$fret'),
          ),
        ),
    ],
  );
  Widget entry() {
    switch (widget.variant) {
      case TabVariant.fretboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tap an intersection · scroll for frets 7–12'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 42),
                      for (var f = 0; f <= 12; f++)
                        SizedBox(
                          width: 44,
                          child: Text('$f', textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                  for (var s = 1; s <= 6; s++)
                    Row(
                      children: [
                        SizedBox(width: 42, child: Text('S$s')),
                        for (var f = 0; f <= 12; f++)
                          SizedBox(
                            width: 44,
                            height: 40,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const RoundedRectangleBorder(),
                              ),
                              key: ValueKey('fretboard-$s-$f'),
                              onPressed: () => put(f, s),
                              child: Text(
                                '$f',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      case TabVariant.fretFirst:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              armedFret == null
                  ? '1. Choose fret'
                  : '2. Tap destination string for fret $armedFret',
            ),
            keypad(),
            const SizedBox(height: 8),
            stringButtons(),
          ],
        );
      case TabVariant.activeString:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose string once, then tap frets'),
            stringButtons(),
            const SizedBox(height: 8),
            keypad(),
          ],
        );
      case TabVariant.wheel:
        return Column(
          children: [
            stringButtons(),
            SizedBox(
              height: 110,
              child: ListWheelScrollView.useDelegate(
                key: const Key('fret-wheel'),
                itemExtent: 42,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (v) => setState(() => wheelFret = v),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 13,
                  builder: (_, f) => Center(
                    child: Text(
                      '$f',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: f == wheelFret
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => put(wheelFret, doc.string),
              child: Text('Place fret $wheelFret on string ${doc.string}'),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(variantNames[widget.variant.index]),
      actions: [
        if (started)
          TextButton(
            onPressed: finishing ? null : finish,
            child: const Text('Finish'),
          ),
      ],
    ),
    body: Listener(
      onPointerDown: (e) {
        if (started && !paused && !finishing) pointers[e.pointer] = e.position;
      },
      onPointerMove: (e) {
        final origin = pointers[e.pointer];
        if (origin != null && (e.position - origin).distance > 12) {
          dragged.add(e.pointer);
        }
      },
      onPointerUp: (e) {
        if (pointers.remove(e.pointer) != null) {
          if (dragged.remove(e.pointer)) {
            gestures++;
          } else {
            taps++;
          }
        }
      },
      onPointerCancel: (e) {
        pointers.remove(e.pointer);
        dragged.remove(e.pointer);
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            widget.practice
                ? 'Practice · not a scored trial'
                : widget.correction
                ? 'Correction · fix ten mistakes'
                : 'Creation · enter the reference riff',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const Text(
            'S1 = high E, S6 = low E. Position numbers are order only, not rhythm.',
          ),
          ExpansionTile(
            key: ValueKey('reference-$started'),
            initiallyExpanded: !started,
            title: const Text('Reference riff & task'),
            children: [
              _TabGrid(columns: referenceRiff()),
              if (widget.correction)
                ...correctionInstructions.map(
                  (s) => Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(s),
                    ),
                  ),
                )
              else
                const Text(
                  'Start empty. Match every note above, including the last three-note chord. Turn Auto advance off to stack notes at one position.',
                ),
            ],
          ),
          if (!started) ...[
            const Text(
              'Review the task before starting. Tap cells to select a note; use Move then tap an empty destination. Delete note removes one note; + position inserts a column. Undo/redo works in every variant.',
            ),
            FilledButton(
              onPressed: start,
              child: Text(
                widget.practice ? 'Start practice' : 'Start timed task',
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${clock.elapsed.inSeconds}s · $taps taps · $undos undo',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      paused = !paused;
                      if (paused) {
                        clock.stop();
                        interruptions++;
                      } else {
                        clock.start();
                      }
                    });
                  },
                  child: Text(paused ? 'Resume' : 'Pause'),
                ),
              ],
            ),
            if (paused) const Text('Paused. Resume when ready.'),
            AbsorbPointer(
              absorbing: paused || finishing,
              child: Opacity(
                opacity: paused ? 0.4 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TabGrid(
                      columns: doc.columns,
                      position: doc.position,
                      string: doc.string,
                      onCell: selectCell,
                      controller: scroll,
                    ),
                    Text(
                      'Position ${doc.position + 1} · String ${doc.string}${moving == null ? '' : ' · Tap move destination'}',
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Previous position',
                          onPressed: doc.position > 0
                              ? () => setState(() => doc.position--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Next position',
                          onPressed: () {
                            setState(doc.next);
                            followCursor();
                          },
                          icon: const Icon(Icons.chevron_right),
                        ),
                        FilterChip(
                          label: const Text('Auto advance'),
                          selected: doc.advance,
                          onSelected: (v) => setState(() => doc.advance = v),
                        ),
                        IconButton(
                          tooltip: 'Undo',
                          onPressed: doc.canUndo
                              ? () {
                                  setState(() {
                                    doc.undo();
                                    undos++;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.undo),
                        ),
                        IconButton(
                          tooltip: 'Redo',
                          onPressed: doc.canRedo
                              ? () => setState(doc.redo)
                              : null,
                          icon: const Icon(Icons.redo),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => setState(doc.deleteNote),
                          child: const Text('Delete note'),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => moving = moving == null
                                ? (doc.position, doc.string)
                                : null,
                          ),
                          child: Text(
                            moving == null ? 'Move note' : 'Cancel move',
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(doc.insertPosition),
                          child: const Text('+ position'),
                        ),
                        TextButton(
                          onPressed: () => setState(doc.deletePosition),
                          child: const Text('Delete position'),
                        ),
                      ],
                    ),
                    const Divider(),
                    entry(),
                    TextButton(
                      onPressed: () {
                        checks++;
                        final difference = tabDifferences(
                          doc.columns,
                          referenceRiff(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$difference note differences from the reference.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Check against reference'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _TabGrid extends StatelessWidget {
  const _TabGrid({
    required this.columns,
    this.position,
    this.string,
    this.onCell,
    this.controller,
  });
  final List<TabColumn> columns;
  final int? position, string;
  final void Function(int, int)? onCell;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    controller: controller,
    child: Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 32),
            for (var p = 0; p < columns.length; p++)
              SizedBox(
                width: 48,
                height: 24,
                child: Text('${p + 1}', textAlign: TextAlign.center),
              ),
          ],
        ),
        for (var s = 1; s <= 6; s++)
          Row(
            children: [
              SizedBox(width: 32, child: Text('S$s')),
              for (var p = 0; p < columns.length; p++)
                SizedBox(
                  width: 48,
                  height: onCell == null ? 25 : 36,
                  child: Semantics(
                    label:
                        'Position ${p + 1}, string $s, ${columns[p][s] ?? 'empty'}',
                    button: onCell != null,
                    child: InkWell(
                      key: ValueKey('tab-cell-$p-$s'),
                      onTap: onCell == null ? null : () => onCell!(p, s),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p == position
                              ? (s == string
                                    ? const Color(0xFFB8DCCC)
                                    : const Color(0xFFEAF0E6))
                              : null,
                          border: const Border(
                            bottom: BorderSide(color: Colors.grey, width: 0.5),
                          ),
                        ),
                        child: Text('${columns[p][s] ?? '—'}'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

class _TrialFeedback extends StatefulWidget {
  const _TrialFeedback({required this.remaining, required this.practice});
  final int remaining;
  final bool practice;
  @override
  State<_TrialFeedback> createState() => _TrialFeedbackState();
}

class _TrialFeedbackState extends State<_TrialFeedback> {
  double? frustration;
  String hand = 'Not tried', gaze = 'Not observed';
  final mistakes = TextEditingController(), comments = TextEditingController();
  @override
  void dispose() {
    mistakes.dispose();
    comments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.remaining == 0
          ? 'Riff matches'
          : '${widget.remaining} note differences remain',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Finish with the current result, or continue editing. No interaction has been chosen as the winner.',
          ),
          Text(
            'Frustration: ${frustration?.round().toString() ?? 'not rated'} / 7',
          ),
          Slider(
            value: frustration ?? 4,
            min: 1,
            max: 7,
            divisions: 6,
            onChanged: (v) => setState(() => frustration = v),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: hand,
            decoration: const InputDecoration(labelText: 'One-handed use'),
            items: [
              'Not tried',
              'Easy',
              'Possible but awkward',
              'Needed two hands',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => hand = v!),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: gaze,
            decoration: const InputDecoration(
              labelText: 'Looking between controls and tab',
            ),
            items: [
              'Not observed',
              'Rarely',
              'Sometimes',
              'Often',
              'Constantly',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => gaze = v!),
          ),
          TextField(
            controller: mistakes,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Mistakes noticed (optional count)',
            ),
          ),
          TextField(
            controller: comments,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'What felt good or frustrating?',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Continue editing'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, <String, Object?>{
          'frustration': frustration?.round(),
          'oneHanded': hand,
          'gazeShifts': gaze,
          'reportedMistakes': int.tryParse(mistakes.text),
          'comments': comments.text,
        }),
        child: const Text('Finish trial'),
      ),
    ],
  );
}
