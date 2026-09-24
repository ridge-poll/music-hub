import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final previewKey = GlobalKey();
Widget previewHost(Widget child) =>
    RepaintBoundary(key: previewKey, child: child);
Future<void> preparePreview(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (Platform.environment['MUSIC_HUB_SCREENSHOTS'] == null) return;
  await tester.runAsync(() async {
    for (final font in {
      'Roboto': '/System/Library/Fonts/SFNS.ttf',
      'Courier': '/System/Library/Fonts/Courier.ttc',
      'MaterialIcons':
          '/Applications/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
}

Future<void> capturePreview(WidgetTester tester, String name) async {
  final directory = Platform.environment['MUSIC_HUB_SCREENSHOTS'];
  if (directory == null) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}
