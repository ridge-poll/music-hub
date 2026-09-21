import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:music_hub/audio_files.dart';
import 'package:music_hub/document.dart';
import 'package:music_hub/main.dart';
import 'package:music_hub/store.dart';

void main() {
  testWidgets(
    'song tab keeps keyboard across cells and added blocks, then saves/reopens verbatim',
    (tester) async {
      sqfliteFfiInit();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('tab_ui_'),
      ))!;
      final store = (await tester.runAsync(
        () => MusicStore.open(
          factory: databaseFactoryFfi,
          location: '${root.path}/db.sqlite',
        ),
      ))!;
      final song = SongDocument(title: 'Grid song');
      await tester.runAsync(() => store.save(song));
      final boundaryKey = GlobalKey();
      final screenshots = Platform.environment['MUSIC_HUB_SCREENSHOTS'];
      if (screenshots != null) {
        await tester.runAsync(() async {
          for (final font in {
            'Roboto': '/System/Library/Fonts/SFNS.ttf',
            'Courier': '/System/Library/Fonts/Courier.ttc',
            'MaterialIcons':
                '/Applications/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          }.entries) {
            final loader = FontLoader(font.key);
            loader.addFont(
              File(
                font.value,
              ).readAsBytes().then((b) => ByteData.sublistView(b)),
            );
            await loader.load();
          }
        });
      }
      Future<void> flush() async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      Finder cell(int c, int r) => find.byKey(ValueKey('tab-cell-$c-$r'));
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MusicHub(store: store, files: AudioFiles(root)),
        ),
      );
      await flush();
      expect(find.text('Tab lab'), findsNothing);
      await tester.tap(find.text('Grid song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab'));
      await tester.pump();
      await flush();
      expect(find.byType(TextField), findsNWidgets(72));
      await tester.tap(cell(0, 0));
      await tester.enterText(cell(0, 0), r' 7\6 :) ');
      expect(tester.testTextInput.isVisible, true);
      await tester.tap(find.byTooltip('Next cell'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell(1, 0)).focusNode!.hasFocus, true);
      expect(tester.testTextInput.isVisible, true);
      await tester.enterText(cell(1, 0), '0h2\n 🎸 ');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell(2, 0)).focusNode!.hasFocus, true);
      expect(tester.testTextInput.isVisible, true);
      await tester.enterText(cell(2, 0), '3/5');
      await tester.tap(find.byTooltip('String below'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell(2, 1)).focusNode!.hasFocus, true);
      await tester.enterText(cell(2, 1), ':)');
      if (screenshots != null) {
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        await flush();
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$screenshots/tab-grid.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.tap(find.byTooltip('Add block'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(cell(12, 1)).focusNode!.hasFocus, true);
      expect(tester.testTextInput.isVisible, true);
      await tester.enterText(cell(12, 1), '  x ');
      await tester.tap(find.text('Save'));
      await flush();
      final saved = (await tester.runAsync(
        () => store.loadTab(song.arrangementId),
      ))!;
      expect(saved.positions.length, 24);
      expect(saved.positions[0].cells[0], r' 7\6 :) ');
      expect(saved.positions[1].cells[0], '0h2\n 🎸 ');
      tester.view.resetViewInsets();
      await tester.tap(find.byTooltip('Back to song'));
      await tester.pump();
      await flush();
      await tester.tap(find.text('Tab'));
      await tester.pump();
      await flush();
      expect(tester.widget<TextField>(cell(12, 1)).controller!.text, '  x ');
      expect(tester.widget<TextField>(cell(2, 0)).controller!.text, '3/5');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await store.close();
        await root.delete(recursive: true);
      });
    },
  );
}
