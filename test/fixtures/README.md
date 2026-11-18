TensorFlow example photographs used by the real-inference regression tests:
- labrador.jpg: https://storage.googleapis.com/download.tensorflow.org/example_images/YellowLabradorLooking_new.jpg
- grace_hopper.jpg: https://storage.googleapis.com/download.tensorflow.org/example_images/grace_hopper.jpg

These fixtures are not bundled in the Android app.
- coffee.jpg: https://raw.githubusercontent.com/tensorflow/tfjs-models/master/mobilenet/demo/coffee.jpg
- cat_indoor.jpg: https://raw.githubusercontent.com/tensorflow/tfjs-examples/master/mobilenet/cat.jpg

predictions.json captures actual two-view EfficientNet-Lite4 results for the
Labrador fixture, used for stable UI previews. Regenerate it by running:
CAPTURE_PREDICTIONS=1 python3 tool/test_native.py test/widget_test.dart
