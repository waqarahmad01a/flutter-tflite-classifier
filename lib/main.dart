import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'views/image_classifier_view.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['EfficientNet-Lite4'],
        await rootBundle.loadString('assets/MODEL_LICENSE.txt'));
  });
  runApp(const MyApp());
}

class AppTheme {
  static ThemeData forBrightness(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge!
            .copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.7),
        headlineSmall: base.textTheme.headlineSmall!
            .copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
        titleLarge:
            base.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600),
        titleMedium:
            base.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle:
            base.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home, this.themeMode = ThemeMode.system});
  final Widget? home;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'Image Classifier',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forBrightness(Brightness.light),
        darkTheme: AppTheme.forBrightness(Brightness.dark),
        themeMode: themeMode,
        home: home ?? const ImageClassifierView(),
      );
}
