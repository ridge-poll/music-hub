import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/main.dart';
import 'package:music_hub/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('create lyrics and chord, save, reopen, enter performance mode', (
    tester,
  ) async {
    sqfliteFfiInit();
    final store = (await tester.runAsync(
      () => MusicStore.open(
        factory: databaseFactoryFfi,
        location: inMemoryDatabasePath,
      ),
    ))!;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock'),
          (call) async => null,
        );
    await tester.pumpWidget(MusicHub(store: store));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('New song'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('title')), 'Porch light');
    await tester.enterText(
      find.byKey(const ValueKey('lyric-1')),
      'Take the long way home',
    );
    await tester.tap(find.text('Chord'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Am',
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to songs'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Porch light'));
    await tester.pumpAndSettle();
    expect(find.text('Take the long way home'), findsWidgets);
    await tester.tap(find.byTooltip('Performance mode'));
    await tester.pumpAndSettle();
    expect(find.byType(PerformanceScreen), findsOneWidget);
    expect(find.text('Am'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(store.close);
  });
}
