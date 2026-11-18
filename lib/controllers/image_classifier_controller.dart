import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/tflite_service.dart';

class ImageClassifierController extends GetxController {
  final TfliteService _tfliteService = TfliteService();
  final ImagePicker _picker = ImagePicker();

  final isLoading = false.obs;
  final isAnalyzing = false.obs;
  final isModelLoaded = false.obs;
  final modelStatus = 'Preparing classifier…'.obs;
  final selectedImage = Rx<File?>(null);
  final predictions = <Prediction>[].obs;
  final errorMessage = RxnString();
  final analysisMilliseconds = RxnInt();
  final classificationResult = 'Choose a photo or take a picture.'.obs;

  bool get canPick => isModelLoaded.value && !isLoading.value;

  @override
  void onInit() {
    super.onInit();
    unawaited(initModel());
  }

  Future<void> initModel() async {
    if (isLoading.value) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _tfliteService.loadModel();
      if (isClosed) return;
      isModelLoaded.value = true;
      modelStatus.value = 'Ready to explore';
    } catch (error, stack) {
      log('Model initialization failed', error: error, stackTrace: stack);
      if (isClosed) return;
      modelStatus.value = 'Classifier unavailable';
      errorMessage.value =
          'The classifier could not start. Tap Retry to try again.';
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    if (!canPick) return;
    isLoading.value = true;
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (image == null || isClosed) return;
      selectedImage.value = File(image.path);
      await runClassification(selectedImage.value!);
    } on PlatformException catch (error) {
      if (!isClosed) {
        errorMessage.value = error.code.contains('access_denied')
            ? 'Allow camera or photo access in Settings, then try again.'
            : 'The photo picker could not open. Please try again.';
      }
    } catch (error, stack) {
      log('Image selection failed', error: error, stackTrace: stack);
      if (!isClosed) {
        errorMessage.value = 'Could not read this photo. Try another image.';
      }
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  Future<void> runClassification(File image) async {
    if (isAnalyzing.value || !isModelLoaded.value) return;
    isLoading.value = true;
    isAnalyzing.value = true;
    errorMessage.value = null;
    predictions.clear();
    analysisMilliseconds.value = null;
    final timer = Stopwatch()..start();
    try {
      final result = await _tfliteService.classifyImage(image);
      if (isClosed) return;
      predictions.assignAll(result);
      analysisMilliseconds.value = timer.elapsedMilliseconds;
      classificationResult.value = result
          .map((p) => '${p.label}: ${(p.confidence * 100).toStringAsFixed(1)}%')
          .join('\n');
    } catch (error, stack) {
      log('Classification failed', error: error, stackTrace: stack);
      if (!isClosed) {
        errorMessage.value =
            'This photo could not be analyzed. Try a JPG or PNG image.';
      }
    } finally {
      if (!isClosed) {
        isAnalyzing.value = false;
        isLoading.value = false;
      }
    }
  }

  void clearPhoto() {
    if (!canPick) return;
    selectedImage.value = null;
    predictions.clear();
    errorMessage.value = null;
    analysisMilliseconds.value = null;
  }

  Future<void> retry() async {
    if (isLoading.value) return;
    if (!isModelLoaded.value) {
      await initModel();
    } else if (selectedImage.value != null) {
      await runClassification(selectedImage.value!);
    } else {
      errorMessage.value = null;
    }
  }

  @override
  void onClose() {
    unawaited(_tfliteService.dispose());
    super.onClose();
  }
}
