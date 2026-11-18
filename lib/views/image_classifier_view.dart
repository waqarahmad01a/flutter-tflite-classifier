import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/image_classifier_controller.dart';
import '../services/tflite_service.dart';

class ImageClassifierView extends StatelessWidget {
  const ImageClassifierView({super.key, this.controller});
  final ImageClassifierController? controller;

  @override
  Widget build(BuildContext context) {
    final ImageClassifierController c = controller ??
        Get.put<ImageClassifierController>(ImageClassifierController());
    final scheme = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.center_focus_strong_rounded, color: scheme.primary),
          const SizedBox(width: 12),
          const Flexible(
              child: Text('Image classifier',
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
              onPressed: () => _showAbout(context),
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'About image recognition'),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
          top: false,
          child: Column(children: [
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final compact = constraints.maxHeight < 420;
              return SingleChildScrollView(
                padding:
                    EdgeInsets.fromLTRB(wide ? 32 : 24, 12, wide ? 32 : 24, 24),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Obx(() {
                          final hasPhoto = c.selectedImage.value != null;
                          final heading = hasPhoto
                              ? 'A closer look.'
                              : 'What’s in your photo?';
                          final photo = _PhotoPanel(controller: c);
                          final results = _ResultPanel(controller: c);
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(heading,
                                    style: compact
                                        ? type.headlineSmall
                                        : type.headlineLarge),
                                const SizedBox(height: 8),
                                Text(
                                    hasPhoto
                                        ? 'The closest matches for your photo.'
                                        : 'Take a photo or choose one to discover more.',
                                    style: type.bodyLarge!.copyWith(
                                        color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 24),
                                if (wide)
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 6, child: photo),
                                        const SizedBox(width: 32),
                                        Expanded(flex: 5, child: results),
                                      ])
                                else ...[
                                  photo,
                                  const SizedBox(height: 24),
                                  results,
                                ],
                              ]);
                        }))),
              );
            })),
            _PhotoActions(controller: c),
          ])),
    );
  }

  void _showAbout(BuildContext context) {
    final type = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A little more about your matches',
                        style: type.headlineSmall),
                    const SizedBox(height: 16),
                    const Text(
                        'Your photos stay on this device. Recognition runs offline across 1,000 ImageNet categories.'),
                    const SizedBox(height: 12),
                    const Text(
                        'The classifier checks both a closer crop and the full photo. A clear, well-lit image with one main subject usually works best.'),
                    const SizedBox(height: 12),
                    const Text(
                        'Confidence scores are model estimates, not guarantees. It may confuse similar objects or subjects outside its categories.'),
                    const SizedBox(height: 24),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'))),
                  ]))),
    );
  }
}

class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel({required this.controller});
  final ImageClassifierController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Obx(() {
      final file = controller.selectedImage.value;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant)),
          child: AspectRatio(
            aspectRatio: file == null &&
                    MediaQuery.textScalerOf(context).scale(14) > 17
                ? 0.85
                : file == null
                    ? 1.15
                    : MediaQuery.orientationOf(context) == Orientation.landscape
                        ? 2.2
                        : 1.5,
            child: file == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 64, color: scheme.primary),
                          const SizedBox(height: 20),
                          Text('Start with a photo',
                              style: type.titleLarge,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                              'Animals, plants, everyday objects\nand a world of possibilities.',
                              style: type.bodyMedium!
                                  .copyWith(color: scheme.onSurfaceVariant),
                              textAlign: TextAlign.center),
                        ]))
                : Semantics(
                    label: 'Selected photo for classification',
                    image: true,
                    child: Image.file(file,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: scheme.error, size: 48)))),
          ),
        ),
        if (file != null)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: controller.canPick ? controller.clearPhoto : null,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Clear photo'),
              )),
      ]);
    });
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.controller});
  final ImageClassifierController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Obx(() {
      final error = controller.errorMessage.value;
      if (error != null) {
        return Semantics(
            liveRegion: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline_rounded, color: scheme.error, size: 28),
              const SizedBox(height: 12),
              Text(
                  controller.isModelLoaded.value
                      ? 'Let’s try another look.'
                      : 'Couldn’t start the classifier.',
                  style: type.titleLarge),
              const SizedBox(height: 8),
              Text(error,
                  style: type.bodyMedium!
                      .copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed:
                      controller.isLoading.value ? null : controller.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry')),
            ]));
      }
      if (controller.isAnalyzing.value || !controller.isModelLoaded.value) {
        return Semantics(
            liveRegion: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  controller.isAnalyzing.value
                      ? 'Looking closer…'
                      : 'Preparing your classifier…',
                  style: type.titleLarge),
              const SizedBox(height: 8),
              Text(
                  controller.isAnalyzing.value
                      ? 'Checking your photo. Everything stays on this device.'
                      : 'Your offline model will be ready in a moment.',
                  style: type.bodyMedium!
                      .copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              const LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(4))),
            ]));
      }
      final predictions = controller.predictions.toList();
      if (predictions.isEmpty) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.light_mode_outlined, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('A clearer photo, a better match.',
                    style: type.titleMedium),
                const SizedBox(height: 4),
                Text('Use good lighting and keep one subject in focus.',
                    style: type.bodyMedium!
                        .copyWith(color: scheme.onSurfaceVariant)),
              ])),
        ]);
      }
      final best = predictions.first;
      final uncertain = best.confidence < 0.35 ||
          (predictions.length > 1 &&
              best.confidence - predictions[1].confidence < 0.1);
      final milliseconds = controller.analysisMilliseconds.value;
      return Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Column(
                key: ValueKey(best.label),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PredictionRow(prediction: best, primary: true),
                  const SizedBox(height: 12),
                  if (uncertain)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                            'A possible match. Try a closer, well-lit photo to be more certain.',
                            style: type.bodyMedium!
                                .copyWith(color: scheme.onSurfaceVariant))),
                  const SizedBox(height: 12),
                  Text('Other possibilities', style: type.titleMedium),
                  const SizedBox(height: 16),
                  for (final prediction in predictions.skip(1))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _PredictionRow(prediction: prediction)),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(children: [
                    Icon(Icons.verified_user_outlined,
                        color: scheme.onSurfaceVariant, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            milliseconds == null
                                ? 'Analyzed on this device'
                                : 'Analyzed in ${(milliseconds / 1000).toStringAsFixed(1)} s · Offline',
                            style: type.bodySmall!
                                .copyWith(color: scheme.onSurfaceVariant))),
                  ]),
                ]),
          ));
    });
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.prediction, this.primary = false});
  final Prediction prediction;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final label = prediction.label.isEmpty
        ? 'Unknown'
        : prediction.label[0].toUpperCase() + prediction.label.substring(1);
    final confidence = '${(prediction.confidence * 100).toStringAsFixed(1)}%';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: primary ? type.headlineSmall : type.bodyLarge)),
        const SizedBox(width: 16),
        Text(confidence,
            style: (primary ? type.titleLarge : type.bodyLarge)!.copyWith(
                color: primary ? scheme.primary : scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
      if (primary)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Model confidence',
                style:
                    type.bodySmall!.copyWith(color: scheme.onSurfaceVariant))),
      const SizedBox(height: 10),
      Semantics(
          label: '$label, $confidence model confidence',
          excludeSemantics: true,
          child: LinearProgressIndicator(
            value: prediction.confidence,
            minHeight: primary ? 6 : 4,
            color: primary ? scheme.primary : scheme.secondary,
            backgroundColor: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          )),
    ]);
  }
}

class _PhotoActions extends StatelessWidget {
  const _PhotoActions({required this.controller});
  final ImageClassifierController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
        color: scheme.surfaceContainerLow,
        child: SafeArea(
            top: false,
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1088),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Obx(() {
                        final canPick = controller.canPick;
                        final camera = FilledButton.icon(
                            onPressed: canPick
                                ? () => controller.pickImage(ImageSource.camera)
                                : null,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Camera'));
                        final gallery = FilledButton.tonalIcon(
                            onPressed: canPick
                                ? () =>
                                    controller.pickImage(ImageSource.gallery)
                                : null,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'));
                        if (MediaQuery.textScalerOf(context).scale(14) > 22) {
                          return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                camera,
                                const SizedBox(height: 12),
                                gallery
                              ]);
                        }
                        return Row(children: [
                          Expanded(child: camera),
                          const SizedBox(width: 12),
                          Expanded(child: gallery)
                        ]);
                      }),
                    )))));
  }
}
