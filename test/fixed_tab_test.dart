import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_hub/fixed_tab.dart';
import 'package:music_hub/fixed_tab_editor.dart';

void main() {
  final format = TabOverwriteFormatter();
  TextEditingValue value(String text, int offset) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: offset),
  );
  test(
    'typing overwrites; backspace, forward delete and space preserve width',
    () {
      final blank = blankFixedBlock();
      final before = value(blank, 15);
      final typed = format.formatEditUpdate(
        before,
        value(blank.replaceRange(15, 15, '7h9'), 18),
      );
      expect(typed.text, blank.replaceRange(15, 18, '7h9'));
      expect(typed.selection.start, 18);
      final back = format.formatEditUpdate(
        typed,
        value(typed.text.replaceRange(17, 18, ''), 17),
      );
      expect(back.text, blank.replaceRange(15, 18, '7h-'));
      expect(back.selection.start, 17);
      final space = format.formatEditUpdate(
        back,
        value(back.text.replaceRange(17, 17, ' '), 18),
      );
      expect(space.text, back.text);
      expect(space.selection.start, 18);
      final forward = format.formatEditUpdate(
        value(typed.text, 15),
        value(typed.text.replaceRange(15, 16, ''), 15),
      );
      expect(forward.text, blank.replaceRange(15, 18, '-h9'));
      expect(forward.selection.start, 15);
      expect(forward.text.split('\n').every((line) => line.length == 43), true);
    },
  );
  test(
    'selected deletion protects labels, repeated dash backspace uses caret',
    () {
      final blank = blankFixedBlock();
      final back = format.formatEditUpdate(
        value(blank, 20),
        value(blank.replaceRange(19, 20, ''), 19),
      );
      expect(back.text, blank);
      expect(back.selection.start, 19);
      final all = TextEditingValue(
        text: blank,
        selection: TextSelection(baseOffset: 0, extentOffset: blank.length),
      );
      final cleared = format.formatEditUpdate(all, value('', 0));
      expect(cleared.text, blank);
    },
  );
  test('pasting preserves grapheme slots and overflow rejects entire edit', () {
    final blank = blankFixedBlock();
    final unicode = format.formatEditUpdate(
      value(blank, 2),
      value(blank.replaceRange(2, 2, '🎸'), 4),
    );
    expect(unicode.text, blank.replaceRange(2, 3, '🎸'));
    expect(unicode.selection.start, 4);
    var rejected = false;
    final guarded = TabOverwriteFormatter(onOverflow: () => rejected = true);
    final offset = blank.length - 2;
    final old = value(blank, offset);
    expect(
      guarded.formatEditUpdate(
        old,
        value(blank.replaceRange(offset, offset, '12'), offset + 2),
      ),
      old,
    );
    expect(rejected, true);
  });
  test(
    'legacy long rows continue without dropping content; annotations survive',
    () {
      final rows = tabLabels
          .map((label) => '$label|${'1234567890' * 7}|')
          .join('\n');
      final fitted = fitLegacyTab('$rows\n  annotation\t 🎸\n');
      final blocks = fitted.$1.split('\n\n');
      expect(blocks.length, 2);
      for (var r = 0; r < 6; r++) {
        final restored = blocks
            .map((b) => b.split('\n')[r].substring(2, 42))
            .join();
        expect(restored, '${'1234567890' * 7}${'-' * 10}');
      }
      expect(fitted.$2, '  annotation\t 🎸\n');
    },
  );
  testWidgets('fixed rows fit a narrow phone even with larger system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: blankFixedBlock());
    final undo = UndoHistoryController();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: FixedTabEditor(
              controller: controller,
              undoController: undo,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final RenderEditable editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final boxes = editable.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 43),
    );
    expect(boxes.map((b) => b.top).toSet().length, 1);
    expect(boxes.every((b) => b.right <= editable.size.width), true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    undo.dispose();
  });
}
