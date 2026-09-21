// Throwaway Stage 4 model. Not connected to songs, arrangements or tab_documents.
typedef TabColumn = Map<int, int>; // String 1 (high E) .. 6 (low E) -> fret.
List<TabColumn> copyTab(List<TabColumn> source) =>
    source.map((c) => Map<int, int>.of(c)).toList();
List<TabColumn> referenceRiff() => [
  {6: 0},
  {6: 3},
  {6: 5},
  {5: 0},
  {5: 2},
  {4: 0},
  {4: 2},
  {3: 0},
  {2: 0},
  {2: 3},
  {1: 0},
  {1: 0, 2: 0, 3: 1},
];
List<TabColumn> correctionRiff() => [
  {6: 1},
  {6: 4},
  {5: 5},
  {5: 0, 1: 7},
  {5: 2},
  {},
  {4: 2},
  {3: 2},
  {3: 0},
  {2: 5},
  {1: 2},
  {1: 0},
];
const correctionInstructions = [
  '1. Position 1: string 6, fret 1 → 0.',
  '2. Position 2: string 6, fret 4 → 3.',
  '3. Position 3: move fret 5 from string 5 to string 6.',
  '4. Position 4: delete the extra string 1, fret 7.',
  '5. Position 6: insert string 4, fret 0 into the gap.',
  '6. Position 8: string 3, fret 2 → 0.',
  '7. Position 9: move fret 0 from string 3 to string 2.',
  '8. Position 10: string 2, fret 5 → 3.',
  '9. Position 11: string 1, fret 2 → 0.',
  '10. Position 12: keep string 1 fret 0; add string 2 fret 0 and string 3 fret 1 to make a chord.',
];

int tabDifferences(List<TabColumn> actual, List<TabColumn> target) {
  final trimmed = copyTab(actual);
  while (trimmed.isNotEmpty && trimmed.last.isEmpty) {
    trimmed.removeLast();
  }
  var errors = 0;
  final length = trimmed.length > target.length
      ? trimmed.length
      : target.length;
  for (var i = 0; i < length; i++) {
    final a = i < trimmed.length ? trimmed[i] : <int, int>{};
    final b = i < target.length ? target[i] : <int, int>{};
    for (var string = 1; string <= 6; string++) {
      if (a[string] != b[string]) errors++;
    }
  }
  return errors;
}

class TabLabDocument {
  TabLabDocument({bool correction = false})
    : columns = correction ? correctionRiff() : [{}];
  List<TabColumn> columns;
  int position = 0, string = 6;
  bool advance = true;
  final List<List<TabColumn>> _undo = [], _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void edit(void Function() action) {
    _undo.add(copyTab(columns));
    _redo.clear();
    action();
  }

  void put(int fret, {int? onString}) {
    edit(() {
      columns[position][onString ?? string] = fret;
    });
    if (advance) next();
  }

  void next() {
    if (position == columns.length - 1) {
      columns.add({});
    }
    position++;
  }

  void deleteNote() => edit(() {
    columns[position].remove(string);
  });
  void insertPosition() => edit(() {
    columns.insert(position, {});
  });
  void deletePosition() => edit(() {
    columns.removeAt(position);
    if (columns.isEmpty) columns.add({});
    position = position.clamp(0, columns.length - 1);
  });
  void move(int fromPosition, int fromString, int toPosition, int toString) =>
      edit(() {
        final fret = columns[fromPosition].remove(fromString);
        if (fret != null) columns[toPosition][toString] = fret;
      });
  void undo() {
    if (!canUndo) return;
    _redo.add(copyTab(columns));
    columns = _undo.removeLast();
    position = position.clamp(0, columns.length - 1);
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(copyTab(columns));
    columns = _redo.removeLast();
    position = position.clamp(0, columns.length - 1);
  }
}
