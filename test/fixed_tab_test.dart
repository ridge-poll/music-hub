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
  TextEditingValue insert(TextEditingValue old, String text) =>
      format.formatEditUpdate(
        old,
        value(
          old.text.replaceRange(old.selection.start, old.selection.end, text),
          old.selection.start + text.length,
        ),
      );
  TextEditingValue backspace(TextEditingValue old) => format.formatEditUpdate(
    old,
    value(
      old.text.replaceRange(old.selection.start - 1, old.selection.start, ''),
      old.selection.start - 1,
    ),
  );
  test('each string flows into its own continuation and closing bars move', () {
    for (var row = 0; row < 6; row++) {
      final layout = FixedTabLayout.blank();
      final old = value(layout.render(), layout.offsetFor(row, 39));
      final typed = insert(old, '7h9');
      final after = FixedTabLayout.read(typed.text)!;
      expect(after.blockCount, 2);
      expect(after.rows[row].sublist(39, 42).join(), '7h9');
      for (var r = 0; r < 6; r++) {
        if (r != row) expect(after.rows[r].every((c) => c == '-'), true);
      }
      expect(after.locate(typed.selection.start), (row: row, position: 42));
      expect(
        typed.text
            .split('\n\n')
            .first
            .split('\n')
            .every((line) => !line.endsWith('|')),
        true,
      );
      expect(
        typed.text
            .split('\n\n')
            .last
            .split('\n')
            .every((line) => line.startsWith('  ') && line.endsWith('|')),
        true,
      );
    }
  });
  test(
    'space advances over dashes across the boundary; backspace collapses only empty final blocks',
    () {
      final layout = FixedTabLayout.blank();
      layout.rows[2][39] = '9';
      layout.appendBlock();
      final before = value(layout.render(), layout.offsetFor(2, 40));
      final collapsed = backspace(before);
      final after = FixedTabLayout.read(collapsed.text)!;
      expect(after.blockCount, 1);
      expect(after.rows[2][39], '9');
      expect(after.locate(collapsed.selection.start), (row: 2, position: 40));
      final erased = backspace(collapsed);
      expect(FixedTabLayout.read(erased.text)!.rows[2][39], '-');
      expect(
        FixedTabLayout.read(
          backspace(value(blankFixedBlock(), 2)).text,
        )!.blockCount,
        1,
      );
    },
  );
  test(
    'another string protects a final block; deleting its last character collapses it',
    () {
      final layout = FixedTabLayout.blank()..appendBlock();
      layout.rows[5][40] = 'x';
      final untouched = backspace(
        value(layout.render(), layout.offsetFor(0, 41)),
      );
      expect(FixedTabLayout.read(untouched.text)!.blockCount, 2);
      expect(FixedTabLayout.read(untouched.text)!.rows[5][40], 'x');
      final collapsed = backspace(
        value(
          untouched.text,
          FixedTabLayout.read(untouched.text)!.offsetFor(5, 41),
        ),
      );
      expect(FixedTabLayout.read(collapsed.text)!.blockCount, 1);
      final spaced = insert(value(blankFixedBlock(), 41), ' ');
      expect(FixedTabLayout.read(spaced.text)!.blockCount, 2);
      expect(FixedTabLayout.read(spaced.text)!.hasContent, false);
    },
  );
  test(
    'Unicode and long single-line paste preserve slots through many blocks',
    () {
      final typed = insert(value(blankFixedBlock(), 2), '🎸7h9${'x' * 82}');
      final layout = FixedTabLayout.read(typed.text)!;
      expect(layout.blockCount, 3);
      expect(layout.rows[0].take(86).join(), '🎸7h9${'x' * 82}');
      expect(layout.locate(typed.selection.start), (row: 0, position: 86));
      final back = backspace(typed);
      expect(FixedTabLayout.read(back.text)!.rows[0][85], '-');
    },
  );
  test(
    'simple six-row ASCII paste wraps without interpreting or losing characters',
    () {
      final raw = tabLabels
          .asMap()
          .entries
          .map((e) => '${e.value}|${'${e.key}' * 45}0h2  |')
          .join('\n');
      final typed = insert(value(blankFixedBlock(), 2), raw);
      final layout = FixedTabLayout.read(typed.text)!;
      expect(layout.blockCount, 2);
      for (var r = 0; r < 6; r++) {
        expect(layout.rows[r].take(50).join(), '${'$r' * 45}0h2  ');
      }
      // Copy the rendered continuation text and paste it into a blank document.
      final copy = insert(value(blankFixedBlock(), 2), typed.text);
      expect(copy.text, typed.text);
      expect(asciiPasteRows('[Chorus]\nsome annotation'), isNull);
    },
  );
  test(
    'selection clears content across blocks while preserving the layout',
    () {
      final layout = FixedTabLayout.blank()..appendBlock();
      layout.rows[0][39] = '🎸';
      layout.rows[1][0] = 'x';
      layout.rows[5][42] = '7';
      final text = layout.render();
      final cleared = format.formatEditUpdate(
        TextEditingValue(
          text: text,
          selection: TextSelection(baseOffset: 0, extentOffset: text.length),
        ),
        value('', 0),
      );
      expect(FixedTabLayout.read(cleared.text)!.hasContent, false);
      expect(FixedTabLayout.read(cleared.text)!.blockCount, 2);
    },
  );
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
  testWidgets(
    'keyboard stays active as typing grows and backspace collapses a continuation',
    (tester) async {
      final controller = TextEditingController(text: blankFixedBlock());
      final undo = UndoHistoryController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixedTabEditor(
              controller: controller,
              undoController: undo,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('tab-text')));
      controller.selection = TextSelection.collapsed(
        offset: FixedTabLayout.read(controller.text)!.offsetFor(4, 39),
      );
      await tester.pump(const Duration(milliseconds: 700));
      final old = controller.value;
      tester.testTextInput.updateEditingValue(
        value(
          old.text.replaceRange(
            old.selection.start,
            old.selection.start,
            '7h9',
          ),
          old.selection.start + 3,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      var layout = FixedTabLayout.read(controller.text)!;
      expect(layout.rows[4].sublist(39, 42).join(), '7h9');
      expect(layout.blockCount, 2);
      expect(tester.testTextInput.isVisible, true);
      final grown = controller.text;
      expect(undo.value.canUndo, true);
      undo.undo();
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.text, blankFixedBlock());
      undo.redo();
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.text, grown);
      for (var i = 0; i < 2; i++) {
        final old = controller.value;
        tester.testTextInput.updateEditingValue(
          value(
            old.text.replaceRange(
              old.selection.start - 1,
              old.selection.start,
              '',
            ),
            old.selection.start - 1,
          ),
        );
        await tester.pump();
      }
      layout = FixedTabLayout.read(controller.text)!;
      expect(layout.blockCount, 1);
      expect(layout.rows[4][39], '7');
      expect(layout.locate(controller.selection.start), (row: 4, position: 40));
      expect(tester.testTextInput.isVisible, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      undo.dispose();
    },
  );
  testWidgets('fixed rows fit a narrow phone even with larger system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(
      text: (FixedTabLayout.blank()..appendBlock()).render(),
    );
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
    var offset = 0;
    for (final line in controller.text.split('\n')) {
      if (line.isNotEmpty) {
        final boxes = editable.getBoxesForSelection(
          TextSelection(baseOffset: offset, extentOffset: offset + line.length),
        );
        expect(boxes.map((b) => b.top).toSet().length, 1);
        expect(boxes.every((b) => b.right <= editable.size.width), true);
      }
      offset += line.length + 1;
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    undo.dispose();
  });
}
