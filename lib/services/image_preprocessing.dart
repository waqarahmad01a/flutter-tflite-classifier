import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

const classifierInputSize = 300;

img.Image decodePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('This image format could not be decoded.');
  }
  return img.bakeOrientation(decoded);
}

/// EfficientNet-Lite4's evaluation crop and normalization, plus an optional
/// whole-photo view so subjects near the edges are not discarded entirely.
Float32List prepareView(img.Image photo, {bool wholePhoto = false}) {
  img.Image view = photo;
  if (!wholePhoto) {
    // Match the upstream evaluation padding: 300 / (300 + round(300 / 7)).
    final side =
        math.max(1, (math.min(photo.width, photo.height) * 300 / 343).floor());
    view = img.copyCrop(
      photo,
      x: (photo.width - side + 1) ~/ 2,
      y: (photo.height - side + 1) ~/ 2,
      width: side,
      height: side,
    );
  }
  final resized = img.copyResize(
    view,
    width: classifierInputSize,
    height: classifierInputSize,
    interpolation: img.Interpolation.linear,
  );
  final tensor = Float32List(classifierInputSize * classifierInputSize * 3);
  var index = 0;
  for (final pixel in resized) {
    // Normalized channels also handle 16-bit PNGs. Composite transparency over
    // white so invisible RGB values do not become misleading model input.
    final alpha = pixel.aNormalized;
    final white = 1 - alpha;
    tensor[index++] = ((pixel.rNormalized * alpha + white) * 255 - 127) / 128;
    tensor[index++] = ((pixel.gNormalized * alpha + white) * 255 - 127) / 128;
    tensor[index++] = ((pixel.bNormalized * alpha + white) * 255 - 127) / 128;
  }
  return tensor;
}

Float32List preprocessImage(Uint8List bytes, {bool wholePhoto = false}) =>
    prepareView(decodePhoto(bytes), wholePhoto: wholePhoto);
