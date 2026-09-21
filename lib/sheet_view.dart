import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'document.dart';

const sheetFont = 'Courier';

// TextSpan styling preserves one code unit per source character. No widgets,
// replacement spans or normalization are inserted into the editable value.
class SheetController extends TextEditingController {
  SheetController({super.text});
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in chordMarker.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
      );
      cursor = match.end;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    return TextSpan(style: style, children: spans);
  }
}

double sheetWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  );
  var width = 0.0;
  for (final line in text.split('\n')) {
    painter.text = TextSpan(text: line, style: style);
    painter.layout();
    width = math.max(width, painter.width);
  }
  painter.dispose();
  return width;
}

class PlainSheetEditor extends StatelessWidget {
  const PlainSheetEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.undoController,
  });
  final SheetController controller;
  final ValueChanged<String> onChanged;
  final UndoHistoryController undoController;
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: sheetFont,
      fontFamilyFallback: ['monospace'],
      fontSize: 17,
      height: 1.65,
    );
    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(
                constraints.maxWidth,
                sheetWidth(context, value.text, style) + 48,
              ),
              height: constraints.maxHeight,
              child: TextField(
                key: const Key('sheet-text'),
                controller: controller,
                undoController: undoController,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.multiline,
                style: style,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.all(20),
                  hintText:
                      '[Intro]\nC       Em      Am\nPaste or write your lyrics here…\n\nUse {Am} to highlight a chord.',
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PerformanceSheet extends StatelessWidget {
  const PerformanceSheet({super.key, required this.text, required this.size});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: sheetFont,
      fontFamilyFallback: const ['monospace'],
      fontSize: size,
      height: 1.65,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(
          MediaQuery.sizeOf(context).width - 48,
          sheetWidth(context, text, style) + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in text.split('\n')) _line(context, line, style),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String line, TextStyle style) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in chordMarker.allMatches(line)) {
      spans.add(TextSpan(text: line.substring(cursor, match.start)));
      final raw = match.group(0)!;
      final chord = match.group(1)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            label: 'Chord $chord',
            child: Container(
              width: sheetWidth(context, raw, style),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                chord,
                textAlign: TextAlign.center,
                style: style.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    spans.add(TextSpan(text: line.substring(cursor)));
    // Literal blank lines have real height. Horizontal scroll preserves columns.
    return Text.rich(
      TextSpan(children: line.isEmpty ? [const TextSpan(text: ' ')] : spans),
      style: style,
      softWrap: false,
      textDirection: TextDirection.ltr,
    );
  }
}
