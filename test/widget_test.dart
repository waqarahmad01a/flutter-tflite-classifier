import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tflite_classifier/services/image_preprocessing.dart';
import 'package:flutter_tflite_classifier/services/tflite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preprocessing center-crops and normalizes RGB in channel order', () {
    final image = img.Image(width: 6, height: 2);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    for (var y = 0; y < 2; y++) {
      for (var x = 2; x < 4; x++) {
        image.setPixelRgb(x, y, 0, 255, 0);
      }
    }
    final input = preprocessImage(img.encodePng(image));
    expect(input.length, 300 * 300 * 3);
    for (var i = 0; i < input.length; i += 3) {
      expect(input[i], -127 / 128);
      expect(input[i + 1], 1);
      expect(input[i + 2], -127 / 128);
    }
  });

  test('invalid image data fails instead of producing a prediction', () {
    expect(() => preprocessImage(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
  });

  test('16-bit and transparent PNG colors normalize correctly', () {
    final red16 = img.Image(
        width: 8, height: 8, format: img.Format.uint16, numChannels: 3);
    final transparent = img.Image(width: 8, height: 8, numChannels: 4);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        red16.setPixelRgb(x, y, 65535, 0, 0);
        transparent.setPixelRgba(x, y, 255, 0, 0, 0);
      }
    }
    final red = preprocessImage(img.encodePng(red16));
    expect(red[0], 1);
    expect(red[1], -127 / 128);
    expect(red[2], -127 / 128);
    final white = preprocessImage(img.encodePng(transparent));
    expect(white.every((channel) => channel == 1), isTrue);
  });

  test('EXIF phone rotation is applied before inference', () {
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    for (var y = 4; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        image.setPixelRgb(x, y, 0, 0, 255);
      }
    }
    image.exif.imageIfd.orientation = 6;
    final tensor = preprocessImage(img.encodeJpg(image, quality: 100));
    // A clockwise rotation moves the blue bottom half to the left side.
    const left = (150 * 300 + 20) * 3;
    const right = (150 * 300 + 280) * 3;
    expect(tensor[left + 2], greaterThan(0.8));
    expect(tensor[right], greaterThan(0.8));
  });

  test('labels align to the model’s 1,000 ImageNet classes', () async {
    final labels =
        (await rootBundle.loadString('assets/labels.txt')).trim().split('\n');
    expect(labels.length, 1000);
    expect(labels.first, 'tench');
    expect(labels, contains('Labrador retriever'));
  });

  group('real two-view EfficientNet inference', () {
    late TfliteService service;
    setUp(() async {
      service = TfliteService();
      await service.loadModel();
    });
    tearDown(() => service.dispose());

    test('different photos produce different correct, ranked predictions',
        () async {
      final dog =
          await service.classifyImage(File('test/fixtures/labrador.jpg'));
      final person =
          await service.classifyImage(File('test/fixtures/grace_hopper.jpg'));
      // These are real model outputs, including their unmodified probabilities.
      // ignore: avoid_print
      print('DOG: ${dog.map((p) => '${p.label}: ${p.confidence}').join(', ')}');
      // ignore: avoid_print
      print(
          'PERSON: ${person.map((p) => '${p.label}: ${p.confidence}').join(', ')}');
      expect(dog.first.label, 'Labrador retriever');
      expect(person.first.label, 'military uniform');
      expect(dog.first.confidence, greaterThan(0.6));
      expect(person.first.confidence, greaterThan(0.1));
      final coffee =
          await service.classifyImage(File('test/fixtures/coffee.jpg'));
      final cat =
          await service.classifyImage(File('test/fixtures/cat_indoor.jpg'));
      expect(coffee.first.label, 'coffee mug');
      expect(cat.first.label, 'Egyptian cat');
      // ignore: avoid_print
      print('COFFEE: ${coffee.first.label}: ${coffee.first.confidence}');
      // ignore: avoid_print
      print('CAT: ${cat.first.label}: ${cat.first.confidence}');
      if (Platform.environment['CAPTURE_PREDICTIONS'] == '1') {
        File('test/fixtures/predictions.json').writeAsStringSync(jsonEncode(dog
            .map((p) => {'label': p.label, 'confidence': p.confidence})
            .toList()));
      }
      expect(dog.length, 3);
      for (final results in [dog, person]) {
        expect(results.map((p) => p.label), isNot(contains('background')));
        expect(
            results[0].confidence, greaterThanOrEqualTo(results[1].confidence));
        expect(
            results[1].confidence, greaterThanOrEqualTo(results[2].confidence));
      }
    });

    test('a corrupt photo does not prevent the next valid inference', () async {
      final dir = Directory.systemTemp.createTempSync('classifier-test-');
      try {
        final bad = File('${dir.path}/invalid.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        await expectLater(service.classifyImage(bad), throwsFormatException);
        final predictions =
            await service.classifyImage(File('test/fixtures/labrador.jpg'));
        expect(predictions.map((p) => p.label), contains('Labrador retriever'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('concurrent inference is rejected and disposal waits for the worker',
        () async {
      final task = service.classifyImage(File('test/fixtures/labrador.jpg'));
      await expectLater(
          service.classifyImage(File('test/fixtures/grace_hopper.jpg')),
          throwsStateError);
      final closed = service.dispose();
      expect((await task).map((p) => p.label), contains('Labrador retriever'));
      await closed;
      expect(service.isInitialized, isFalse);
      await expectLater(
          service.classifyImage(File('test/fixtures/labrador.jpg')),
          throwsStateError);
    });
  });
}
