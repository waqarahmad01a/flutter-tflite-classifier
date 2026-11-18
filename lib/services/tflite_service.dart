import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_preprocessing.dart';

class Prediction {
  const Prediction(this.label, this.confidence);

  final String label;
  final double confidence;
}

class TfliteService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  Future<List<Prediction>>? _inference;
  bool _disposed = false;

  bool get isInitialized => !_disposed && _interpreter != null;

  Future<void> loadModel() async {
    if (_disposed) throw StateError('The classifier has been closed.');
    if (isInitialized) return;
    final labels = (await rootBundle.loadString('assets/labels.txt'))
        .trim()
        .split(RegExp(r'\r?\n'))
        .map((label) => label.trim())
        .toList();
    final options = InterpreterOptions()..threads = 2;
    Interpreter? interpreter;
    try {
      interpreter = await Interpreter.fromAsset(
        'assets/model.tflite',
        options: options,
      );
      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);
      // EfficientNet-Lite4 uses 300x300 normalized RGB and exactly 1,000
      // ImageNet classes, with no background class.
      if (!listEquals(input.shape, [1, 300, 300, 3]) ||
          input.type != TensorType.float32 ||
          !listEquals(output.shape, [1, 1000]) ||
          output.type != TensorType.float32 ||
          labels.length != 1000 ||
          labels.first != 'tench') {
        throw StateError('The model and its ImageNet labels do not match.');
      }
      if (_disposed) throw StateError('The classifier has been closed.');
      _labels = labels;
      _interpreter = interpreter;
    } catch (_) {
      interpreter?.close();
      rethrow;
    } finally {
      options.delete();
    }
  }

  Future<List<Prediction>> classifyImage(File imageFile) async {
    if (!isInitialized) throw StateError('The model is not ready.');
    if (_inference != null) {
      throw StateError('An image is already being analyzed.');
    }
    // Decoding, resizing and native inference all run away from the UI isolate.
    final task = compute(
      _classify,
      _ClassificationRequest(_interpreter!.address, imageFile.path, _labels),
    );
    _inference = task;
    try {
      return await task;
    } finally {
      _inference = null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _inference;
    } catch (_) {
      // The caller receives inference errors; release resources in either case.
    } finally {
      _interpreter?.close();
      _interpreter = null;
    }
  }
}

class _ClassificationRequest {
  const _ClassificationRequest(this.address, this.path, this.labels);
  final int address;
  final String path;
  final List<String> labels;
}

List<Prediction> _classify(_ClassificationRequest request) {
  final photo = decodePhoto(File(request.path).readAsBytesSync());
  // This worker borrows the native handle. Its owner waits for this task before
  // closing it; never close the borrowed interpreter in this isolate.
  final interpreter = Interpreter.fromAddress(request.address, allocated: true);
  final output = Float32List(request.labels.length);
  // Average two genuine probability distributions, without sharpening scores.
  // The full-frame pass preserves context that the evaluation crop can remove.
  final scores = Float32List(request.labels.length);
  for (final wholePhoto in [false, true]) {
    final input = prepareView(photo, wholePhoto: wholePhoto);
    interpreter.run(input.buffer, output.buffer);
    for (var i = 0; i < scores.length; i++) {
      scores[i] += output[i] / 2;
    }
  }
  final indices = List.generate(scores.length, (i) => i)
    ..sort((a, b) => scores[b].compareTo(scores[a]));
  return indices.take(3).map((index) {
    final score = scores[index];
    if (!score.isFinite || score < 0 || score > 1) {
      throw StateError('The model returned an invalid prediction.');
    }
    return Prediction(request.labels[index], score);
  }).toList();
}
