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
import 'package:music_hub/tab_document.dart';

void main() {
  testWidgets(
    'fixed tab overwrites, fits the phone, appends blocks and saves/reopens',
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
      final song = SongDocument(title: 'ASCII song');
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

      final field = find.byKey(const Key('tab-text'));
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MusicHub(store: store, files: AudioFiles(root)),
        ),
      );
      await flush();
      expect(find.text('Tab lab'), findsNothing);
      await tester.tap(find.text('ASCII song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab'));
      await tester.pump();
      await flush();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, blankTabBlock);
      final control = tester.widget<TextField>(field).controller!;
      await tester.tap(field);
      control.selection = const TextSelection.collapsed(offset: 15);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: blankTabBlock.replaceRange(15, 15, '7h9'),
          selection: const TextSelection.collapsed(offset: 18),
        ),
      );
      await tester.pump();
      final raw = blankTabBlock.replaceRange(15, 18, '7h9');
      expect(control.text, raw);
      expect(tester.testTextInput.isVisible, true);
      expect(tester.widget<TextField>(field).style!.fontFamily, 'Courier');
      expect(tester.getSize(field).width, lessThanOrEqualTo(390));
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
            '$screenshots/tab-fixed.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.tap(find.text('Tab Block'));
      await tester.pumpAndSettle();
      final expected = '$raw\n\n$blankTabBlock';
      expect(tester.widget<TextField>(field).controller!.text, expected);
      await tester.tap(find.text('Save'));
      await flush();
      final saved = (await tester.runAsync(
        () => store.loadTab(song.arrangementId),
      ))!;
      expect(saved.text, expected);
      tester.view.resetViewInsets();
      await tester.tap(find.byTooltip('Back to song'));
      await tester.pump();
      await flush();
      await tester.tap(find.text('Tab'));
      await tester.pump();
      await flush();
      expect(tester.widget<TextField>(field).controller!.text, expected);
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
