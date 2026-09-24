import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fixed_tab.dart';

/// Overwrite only character slots; protect labels, separators and newlines.
class TabOverwriteFormatter extends TextInputFormatter {
  TabOverwriteFormatter({this.onOverflow});
  final VoidCallback? onOverflow;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) return newValue;
    final chars = oldValue.text.characters.toList();
    final offsets = <int>[0];
    for (final char in chars) {
      offsets.add(offsets.last + char.length);
    }
    final slots = <int>[];
    var column = 0;
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == '\n') {
        column = 0;
        continue;
      }
      if (column >= 2 && column < tabColumns + 2) slots.add(i);
      column++;
    }
    if (slots.isEmpty) return oldValue;
    var start = oldValue.selection.start.clamp(0, oldValue.text.length);
    var end = oldValue.selection.end.clamp(start, oldValue.text.length);
    final delta = newValue.text.length - oldValue.text.length;
    String inserted;
    if (start == end && delta < 0) {
      // Native backspace moves the caret left; forward Delete leaves it still.
      if (newValue.selection.start < start) {
        start = math.max(0, start + delta);
      } else {
        end = math.min(oldValue.text.length, end - delta);
      }
      inserted = '';
    } else {
      final count = delta + end - start;
      if (count < 0 || start + count > newValue.text.length) return oldValue;
      inserted = newValue.text.substring(start, start + count);
    }
    var index = slots.indexWhere((i) => offsets[i] >= start);
    if (index < 0) index = slots.length;
    for (final i in slots) {
      if (offsets[i] >= start && offsets[i] < end) chars[i] = '-';
    }
    var cursor = start;
    for (final char in inserted.characters) {
      if (char == '\r') continue;
      if (char == '\n') {
        index = ((index ~/ tabColumns) + 1) * tabColumns;
        continue;
      }
      if (index >= slots.length) {
        onOverflow?.call();
        return oldValue;
      }
      // Space advances through an empty dash; elsewhere it remains literal.
      final slot = slots[index++];
      if (char != ' ' || chars[slot] != '-') chars[slot] = char;
    }
    if (inserted.isNotEmpty) {
      final charIndex = index < slots.length ? slots[index] : slots.last + 1;
      cursor = chars.take(charIndex).join().length;
    } else {
      final slot = slots.indexWhere((i) => offsets[i] >= start);
      cursor = slot >= 0
          ? offsets[slots[slot]]
          : offsets[slots.last] + chars[slots.last].length;
    }
    return TextEditingValue(
      text: chars.join(),
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

class FixedTabEditor extends StatelessWidget {
  const FixedTabEditor({
    super.key,
    required this.controller,
    required this.undoController,
    required this.onChanged,
  });
  final TextEditingController controller;
  final UndoHistoryController undoController;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          const base = TextStyle(
            fontFamily: 'Courier',
            fontFamilyFallback: ['monospace'],
            fontSize: 13,
            letterSpacing: 0,
            wordSpacing: 0,
            fontWeight: FontWeight.normal,
            height: 2,
          );
          final painter = TextPainter(textDirection: TextDirection.ltr);
          var width = 0.0;
          for (final line in value.text.split('\n')) {
            painter.text = TextSpan(text: line, style: base);
            painter.layout();
            width = math.max(width, painter.width);
          }
          painter.dispose();
          final size =
              13 *
              math.min(1.0, (constraints.maxWidth - 32) / math.max(1, width));
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: TextField(
              key: const Key('tab-text'),
              controller: controller,
              undoController: undoController,
              style: base.copyWith(fontSize: size.toDouble()),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              inputFormatters: [
                TabOverwriteFormatter(
                  onOverflow: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Add a Tab Block for more space. This entry was not applied.',
                        ),
                      ),
                    );
                  },
                ),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
              onChanged: onChanged,
            ),
          );
        },
      );
    },
  );
}
