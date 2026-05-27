import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';

import 'router.dart';

// Main application entry point
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData get light => ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF18D777)),
  );

  ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF18D777),
      brightness: Brightness.dark,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: light,
      dark: dark,
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp.router(
        routerConfig: router,
        title: 'CodifyIQ Core Components Catalog',
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
      ),
    );
  }
}
