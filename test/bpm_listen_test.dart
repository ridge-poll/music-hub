import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:music_hub/bpm_listen_screen.dart';
import 'tempo_estimator_test.dart' show rhythmicAudio;

class PcmRecorder extends RecordPlatform {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
  final input = StreamController<Uint8List>.broadcast();
  final states = StreamController<RecordState>.broadcast();
  bool allowed = true, disposed = false;
  int stops = 0;
  @override
  Future<void> create(String id) async {}
  @override
  Future<bool> hasPermission(String id, {bool request = true}) async => allowed;
  @override
  Future<void> setOnConfigChanged(
    String id,
    void Function(RecordConfig)? callback,
  ) async {}
  @override
  Stream<RecordState> onStateChanged(String id) => states.stream;
  @override
  Future<Stream<Uint8List>> startStream(String id, RecordConfig config) async =>
      input.stream;
  @override
  Future<String?> stop(String id) async {
    stops++;
    return null;
  }

  @override
  Future<void> dispose(String id) async {
    disposed = true;
    await input.close();
    await states.close();
  }
}

void main() {
  testWidgets('microphone estimate requires explicit use and stops capture', (
    tester,
  ) async {
    final old = RecordPlatform.instance, fake = PcmRecorder();
    RecordPlatform.instance = fake;
    addTearDown(() => RecordPlatform.instance = old);
    int? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                applied = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(builder: (_) => const BpmListenScreen()),
                );
              },
              child: const Text('Listen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Listen'));
    await tester.pumpAndSettle();
    final samples = rhythmicAudio(120, 22050), bytes = ByteData(22050 * 12 * 2);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(i * 2, (samples[i] * 32767).round(), Endian.little);
    }
    final data = bytes.buffer.asUint8List();
    fake.input.add(data.sublist(0, 101));
    fake.input.add(data.sublist(101));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('120 BPM'), findsOneWidget);
    expect(applied, isNull);
    expect(fake.stops, greaterThanOrEqualTo(1));
    await tester.tap(find.text('Use 120 BPM'));
    await tester.pumpAndSettle();
    expect(applied, 120);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(fake.disposed, true);
  });
  testWidgets('denied microphone permission is recoverable without recording', (
    tester,
  ) async {
    final old = RecordPlatform.instance, fake = PcmRecorder()..allowed = false;
    RecordPlatform.instance = fake;
    addTearDown(() => RecordPlatform.instance = old);
    await tester.pumpWidget(const MaterialApp(home: BpmListenScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Microphone access is off'), findsOneWidget);
    expect(find.text('Listen again'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(fake.disposed, true);
  });
  testWidgets('backgrounding cancels microphone capture and does not resume', (
    tester,
  ) async {
    final old = RecordPlatform.instance, fake = PcmRecorder();
    RecordPlatform.instance = fake;
    addTearDown(() => RecordPlatform.instance = old);
    await tester.pumpWidget(const MaterialApp(home: BpmListenScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Listening…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(fake.stops, greaterThanOrEqualTo(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Listen again'), findsOneWidget);
    expect(find.textContaining('Listening…'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(fake.disposed, true);
  });
}
