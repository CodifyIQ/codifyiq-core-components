# CodifyIQ Core Components

Flutter/Dart package library providing reusable UI widgets for mobile and web applications. Published on pub.dev under MIT license.

## Project Structure

```
codifyiq_core_components/       # Main package directory
├── lib/widgets/                # Widget implementations
├── example/                    # Demo app with GoRouter navigation
├── test/                       # Test files (flutter_test)
├── pubspec.yaml               # Package manifest
└── analysis_options.yaml      # Linting configuration (flutter_lints)
```

## Key Technologies

- **Flutter** >= 1.17.0, **Dart** >= 3.9.2
- **Material Design 3** for theming
- **Dependencies**: gpt_markdown, adaptive_theme, shimmer
- **Build**: Maven (pom.xml) orchestrates Flutter CLI for CI/CD

## Commands

```bash
# Dependencies
flutter pub get

# Format code
dart format .

# Run example app
flutter run -t ./example/main.dart -d chrome

# CI build (Maven)
mvn clean package
```

## Coding Conventions

### Naming
- Classes: `PascalCase` (e.g., `BrightnessButton`)
- Files: `snake_case` (e.g., `brightness_button.dart`)
- Parameters: `camelCase`

### Commits
Gitmoji format with issue numbers:
- `[#15] :sparkles: added brightness button`
- `:sparkles:` new features, `:bug:` fixes, `:bookmark:` releases, `:art:` formatting

### Documentation
- When making changes, always update `CHANGELOG.md` with a summary under the current version. This file is required by Flutter/pub.dev for package publishing.
- Write changelog entries for **external package consumers**, not project committers. Focus on new capabilities, breaking changes, and what consumers can now do. Avoid internal details like dependency moves, refactors, static analysis fixes, or CI changes.

### Static Analysis
- Run `flutter analyze` before committing to ensure there are no warnings or errors. Clean static analysis is required for smooth pub.dev releases.

### Code Style
- Use `const` constructors where possible
- Prefer stateless widgets; use stateful only when necessary
- Document all public APIs with triple-slash (`///`) comments
- Theme-aware colors via `Theme.of(context).colorScheme`
- Single responsibility: one widget per file

### Widget Pattern
```dart
/// Brief description of widget purpose.
///
/// Detailed explanation with usage context.
class MyWidget extends StatelessWidget {
  /// Creates a [MyWidget].
  ///
  /// [paramName] description of parameter.
  const MyWidget({
    super.key,
    required this.paramName,
  });

  /// Documentation for field.
  final String paramName;

  @override
  Widget build(BuildContext context) {
    // Implementation
  }
}
```

## Current Widgets

- **AiProgressIndicator**: Subtle shimmer progress indicator for AI-enabled actions; theme-derived colors customizable via `Theme`/`ColorScheme`
- **BrightnessButton**: Theme toggle (Light/Dark/System) using AdaptiveTheme
- **ErrorRetryWidget**: Error display with retry button
- **TermsAndConditionsWidget**: Scrollable T&C with acceptance checkbox
