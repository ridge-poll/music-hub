import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_hub/tab_lab.dart';

void main() {
  for (final variant in TabVariant.values) {
    testWidgets(
      '${variant.name}: phone-sized entry, undo and correction affordances',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        final screenshotDirectory =
            Platform.environment['MUSIC_HUB_SCREENSHOTS'];
        if (screenshotDirectory != null) {
          await tester.runAsync(() async {
            for (final font in {
              'Roboto': '/System/Library/Fonts/SFNS.ttf',
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
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF276752),
                ),
                scaffoldBackgroundColor: const Color(0xFFF8F6F0),
              ),
              home: TabTrialScreen(
                variant: variant,
                correction: false,
                practice: false,
              ),
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Start timed task'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Start timed task'));
        await tester.pumpAndSettle();
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        switch (variant) {
          case TabVariant.fretboard:
            await tap(find.byKey(const ValueKey('fretboard-6-3')));
          case TabVariant.fretFirst:
            await tap(find.byKey(const ValueKey('fret-key-3')));
            await tap(find.byKey(const ValueKey('trial-string-6')));
          case TabVariant.activeString:
            await tap(find.byKey(const ValueKey('fret-key-3')));
          case TabVariant.wheel:
            await tester.ensureVisible(find.byKey(const Key('fret-wheel')));
            await tester.pumpAndSettle();
            await tester.timedDrag(
              find.byKey(const Key('fret-wheel')),
              const Offset(0, -126),
              const Duration(seconds: 2),
            );
            await tester.pumpAndSettle();
            await tap(find.text('Place fret 3 on string 6'));
        }
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('tab-cell-0-6')),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        await tap(find.byTooltip('Undo'));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('tab-cell-0-6')),
            matching: find.text('—'),
          ),
          findsOneWidget,
        );
        await tap(find.byTooltip('Redo'));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('tab-cell-0-6')),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        if (screenshotDirectory != null) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('tab-cell-0-6')),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$screenshotDirectory/tab-${variant.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tap(find.text('Finish'));
        expect(find.text('Continue editing'), findsOneWidget);
        expect(find.text('Finish trial'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'lab exposes all four variants and both tasks, without song storage',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TabLabScreen()));
      expect(find.text('Create riff'), findsWidgets);
      expect(find.text('Fix 10 errors'), findsWidgets);
      expect(find.text('Practice'), findsWidgets);
      await tester.scrollUntilVisible(find.text('C · Thumbwheel'), 150);
      expect(find.text('C · Thumbwheel'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('A · Fretboard'), -150);
      await tester.tap(find.text('Fix 10 errors').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Position 12: keep string'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Start timed task'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Start timed task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish trial'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Session results (1)'), 150);
      expect(find.text('Session results (1)'), findsOneWidget);
      expect(find.textContaining('remaining note differences'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
