import 'dart:convert';
import 'document.dart';

/// A position is ordering only. Its stable identity can be referenced later;
/// there are no beats, durations, note parsing or musical validation in V1.
class TabPosition {
  TabPosition({String? id, List<String>? cells})
    : id = id ?? ids.v4(),
      cells = cells ?? List.filled(6, '');
  final String id;
  final List<String> cells; // high string to low string
  Map<String, Object> toJson() => {'id': id, 'cells': cells};
}

class TabDocument {
  TabDocument({
    String? id,
    required this.arrangementId,
    this.revision = 0,
    List<TabPosition>? positions,
  }) : id = id ?? ids.v4(),
       positions = positions ?? List.generate(12, (_) => TabPosition());
  final String id, arrangementId;
  int revision;
  final List<TabPosition> positions;
  void addBlock() => positions.addAll(List.generate(12, (_) => TabPosition()));
  String encode() => jsonEncode({
    'formatVersion': 1,
    'id': id,
    'arrangementId': arrangementId,
    'positions': positions.map((p) => p.toJson()).toList(),
  });
  factory TabDocument.decode(String content, int revision) {
    final data = jsonDecode(content) as Map<String, dynamic>;
    if (data['formatVersion'] != 1) {
      throw const FormatException('Unsupported tab format');
    }
    final positions = (data['positions'] as List).map((p) {
      final cells = (p['cells'] as List).cast<String>();
      if (cells.length != 6) {
        throw const FormatException('Expected six string rows');
      }
      return TabPosition(id: p['id'] as String, cells: List.of(cells));
    }).toList();
    if (positions.isEmpty ||
        positions.length % 12 != 0 ||
        positions.map((p) => p.id).toSet().length != positions.length) {
      throw const FormatException('Invalid tab positions');
    }
    return TabDocument(
      id: data['id'] as String,
      arrangementId: data['arrangementId'] as String,
      revision: revision,
      positions: positions,
    );
  }
}
