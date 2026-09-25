import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'fixed_tab.dart';

/// Keep six strings continuous while protecting the visual block structure.
class TabOverwriteFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (oldValue.text == newValue.text) return newValue;
    final layout = FixedTabLayout.read(oldValue.text);
    if (layout == null) return oldValue;
    final start = oldValue.selection.start.clamp(0, oldValue.text.length);
    final end = oldValue.selection.end.clamp(start, oldValue.text.length);
    // Undo/redo supplies a complete prior editor value. Accept a canonical
    // fixed-width layout directly instead of misreading it as one backspace.
    // Ordinary insertions/deletions break that layout and follow slot editing.
    final restored = FixedTabLayout.read(newValue.text);
    final replacementLength =
        newValue.text.length - oldValue.text.length + end - start;
    final selectedSpace =
        end > start &&
        replacementLength == 1 &&
        start < newValue.text.length &&
        newValue.text[start] == ' ';
    if (restored != null &&
        restored.render() == newValue.text &&
        !selectedSpace) {
      return newValue;
    }
    final location = layout.locate(start);
    var row = location.row, position = location.position;
    final delta = newValue.text.length - oldValue.text.length;
    final backspace =
        start == end && delta < 0 && newValue.selection.start < start;
    if (start == end && delta < 0) {
      // Crossing a visual boundary stays on this string. An empty final block
      // collapses before deleting any content in its predecessor.
      final inLast = position >= layout.length - tabColumns;
      if (backspace &&
          inLast &&
          layout.blockCount > 1 &&
          layout.lastBlockEmpty) {
        layout.removeLastBlock();
        position = math.min(position, layout.length);
      } else {
        if (backspace) position = math.max(0, position - 1);
        if (position < layout.length && (!backspace || location.position > 0)) {
          layout.rows[row][position] = '-';
        }
        if (backspace &&
            inLast &&
            layout.blockCount > 1 &&
            layout.lastBlockEmpty) {
          layout.removeLastBlock();
          position = math.min(position, layout.length);
        }
      }
    } else {
      final count = delta + end - start;
      if (count < 0 || start + count > newValue.text.length) return oldValue;
      final inserted = newValue.text.substring(start, start + count);
      layout.clearSelection(start, end);
      final pasted =
          FixedTabLayout.read(inserted)?.rows ?? asciiPasteRows(inserted);
      if (pasted != null) {
        final width = pasted.first.length;
        if (width > 0) layout.ensurePosition(position + width - 1);
        for (var r = 0; r < 6; r++) {
          for (var c = 0; c < width; c++) {
            layout.rows[r][position + c] = pasted[r][c];
          }
        }
        position += width;
      } else {
        for (final char in inserted.characters) {
          if (char == '\r') continue;
          if (char == '\n') {
            final block = position ~/ tabColumns;
            row++;
            position = (block + (row == 6 ? 1 : 0)) * tabColumns;
            row %= 6;
            layout.ensurePosition(position);
            continue;
          }
          layout.ensurePosition(position);
          if (char != ' ' || layout.rows[row][position] != '-') {
            layout.rows[row][position] = char;
          }
          position++;
        }
      }
      // Typing at the end opens the next continuation, ready for the next key.
      if (inserted.isNotEmpty && pasted == null) {
        layout.ensurePosition(position);
      }
    }
    return TextEditingValue(
      text: layout.render(),
      selection: TextSelection.collapsed(
        offset: layout.offsetFor(row, position),
      ),
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
              inputFormatters: [TabOverwriteFormatter()],
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
