import 'package:test/test.dart';
import 'package:music_hub/tab_lab_model.dart';

void main() {
  test('reference creation is achievable from empty with chord stacking', () {
    final doc = TabLabDocument();
    final target = referenceRiff();
    for (var i = 0; i < target.length; i++) {
      doc.position = i;
      doc.advance = false;
      for (final note in target[i].entries) {
        doc.put(note.value, onString: note.key);
      }
      if (i < target.length - 1) doc.next();
    }
    expect(tabDifferences(doc.columns, target), 0);
  });
  test('all ten correction instructions lead exactly to the reference', () {
    final doc = TabLabDocument(correction: true)..advance = false;
    void fret(int position, int string, int fret) {
      doc.position = position - 1;
      doc.put(fret, onString: string);
    }

    fret(1, 6, 0);
    fret(2, 6, 3);
    doc.move(2, 5, 2, 6);
    doc.position = 3;
    doc.string = 1;
    doc.deleteNote();
    fret(6, 4, 0);
    fret(8, 3, 0);
    doc.move(8, 3, 8, 2);
    fret(10, 2, 3);
    fret(11, 1, 0);
    fret(12, 2, 0);
    fret(12, 3, 1);
    expect(tabDifferences(doc.columns, referenceRiff()), 0);
    expect(correctionInstructions.length, 10);
    doc.undo();
    expect(tabDifferences(doc.columns, referenceRiff()), 1);
    doc.redo();
    expect(tabDifferences(doc.columns, referenceRiff()), 0);
  });
  test('position insert/delete undo preserves notes and original fixtures', () {
    final doc = TabLabDocument(correction: true);
    final before = copyTab(doc.columns);
    doc.position = 4;
    doc.insertPosition();
    expect(doc.columns.length, 13);
    doc.deletePosition();
    expect(doc.columns, before);
    doc.undo();
    expect(doc.columns.length, 13);
    expect(correctionRiff().length, 12);
  });
}
