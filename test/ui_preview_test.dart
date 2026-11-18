import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tflite_classifier/main.dart';
import 'package:flutter_tflite_classifier/controllers/image_classifier_controller.dart';
import 'package:flutter_tflite_classifier/services/tflite_service.dart';
import 'package:flutter_tflite_classifier/views/image_classifier_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(
              File('test/fonts/Roboto.ttf').readAsBytesSync()))))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  final captures = <String, (Size, ThemeMode, double, String)>{
    'empty-light': (const Size(390, 844), ThemeMode.light, 1, 'empty'),
    'results-light': (const Size(390, 844), ThemeMode.light, 1, 'results'),
    'results-dark': (const Size(390, 844), ThemeMode.dark, 1, 'results'),
    'tablet': (const Size(1024, 768), ThemeMode.light, 1, 'results'),
    'landscape': (const Size(844, 390), ThemeMode.dark, 1, 'results'),
    'large-text': (const Size(320, 568), ThemeMode.light, 1.3, 'empty'),
    'error': (const Size(390, 844), ThemeMode.light, 1, 'error'),
    'loading': (const Size(390, 844), ThemeMode.light, 1, 'loading'),
  };
  test('theme colors meet text contrast requirements', () {
    for (final brightness in Brightness.values) {
      final s = AppTheme.forBrightness(brightness).colorScheme;
      for (final pair in [
        (s.onSurface, s.surface),
        (s.onPrimary, s.primary),
        (s.onSecondaryContainer, s.secondaryContainer),
        (s.onSurfaceVariant, s.surfaceContainerLow)
      ]) {
        final a = pair.$1.computeLuminance();
        final b = pair.$2.computeLuminance();
        final ratio =
            (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      }
    }
  });
  for (final entry in captures.entries) {
    testWidgets('layout and screenshot: ${entry.key}', (tester) async {
      final (size, themeMode, scale, state) = entry.value;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ImageClassifierController();
      controller.isModelLoaded.value = true;
      if (state == 'results') {
        final data = jsonDecode(
            File('test/fixtures/predictions.json').readAsStringSync()) as List;
        controller.predictions.addAll(data.map((p) => Prediction(
            p['label'] as String, (p['confidence'] as num).toDouble())));
        controller.selectedImage.value = File('test/fixtures/labrador.jpg');
      } else if (state == 'error') {
        controller.errorMessage.value =
            'This photo could not be analyzed. Try a JPG or PNG image.';
      } else if (state == 'loading') {
        controller.isModelLoaded.value = false;
        controller.isLoading.value = true;
      }
      final key = GlobalKey();
      if (state == 'results') {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.runAsync(() => precacheImage(
              FileImage(controller.selectedImage.value!),
              tester.element(find.byType(SizedBox).first),
            ));
      }
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MyApp(
            themeMode: themeMode,
            home: MediaQuery(
                data: MediaQueryData(
                    size: size, textScaler: TextScaler.linear(scale)),
                child: ImageClassifierView(controller: controller)),
          )));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      if (state == 'loading') {
        final camera = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Camera'));
        expect(camera.onPressed, isNull);
      }
      if (state == 'results') {
        expect(find.text('Labrador retriever'), findsOneWidget);
        expect(find.text('74.9%'), findsOneWidget);
      }
      await expectLater(
          find.byKey(key), matchesGoldenFile('goldens/${entry.key}.png'));
      if (entry.key == 'empty-light') {
        await tester.tap(find.byTooltip('About image recognition'));
        await tester.pumpAndSettle();
        expect(find.text('A little more about your matches'), findsOneWidget);
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.text('A little more about your matches'), findsNothing);
      }
      if (entry.key == 'results-light') {
        await tester.tap(find.text('Clear photo'));
        await tester.pumpAndSettle();
        expect(controller.selectedImage.value, isNull);
        expect(controller.predictions, isEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
