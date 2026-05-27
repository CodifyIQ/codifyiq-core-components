# CodifyIQ Components

A Melos-managed monorepo of small, focused Flutter UI packages. Each widget is published to
pub.dev as its own package under the `codifyiq.com` verified publisher (MIT license), so a
consumer only pulls the dependencies of the widgets it actually imports. Heavy native deps
(`pdfrx`, `just_audio`) are quarantined in their own packages.

## Project Structure

```
codifyiq-core-components/        # Git repo (Melos + native Dart pub workspace)
├── pubspec.yaml                 # Workspace root + Melos config (publish_to: none)
├── analysis_options.yaml        # Shared flutter_lints config for all packages
├── README.md                    # Suite index (package table, migration guide)
├── packages/
│   └── codifyiq_<widget>/        # One published package per widget
│       ├── lib/
│       │   ├── codifyiq_<widget>.dart   # Public barrel
│       │   └── src/                      # Implementation (private)
│       ├── test/
│       ├── pubspec.yaml          # Declares ONLY the deps it imports; resolution: workspace
│       ├── CHANGELOG.md          # Per-package, required by pub.dev
│       ├── README.md
│       └── LICENSE
└── example/                     # Shared demo app (GoRouter catalog of all widgets)
```

## Key Technologies

- **Flutter** >= 3.41.0, **Dart** SDK ^3.10.0
- **Material Design 3** for theming
- **Monorepo**: [Melos](https://melos.invertase.dev) 7 over native Dart pub workspaces
- Each package depends only on what it imports (e.g. `pdfrx`, `just_audio`, `photo_view`,
  `gpt_markdown`, `shimmer`, `adaptive_theme`); the workspace root carries no runtime deps.

## Commands

```bash
# One-time: install Melos
dart pub global activate melos

# Resolve all packages (or: flutter pub get at the workspace root)
melos bootstrap

# Analyze / format / test every package
melos run analyze
melos run test

# Run the example catalog
flutter run -t example/lib/main.dart -d chrome
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
- When changing a package, update **that package's** `CHANGELOG.md` (`packages/codifyiq_<widget>/CHANGELOG.md`) with a summary under the current version. This file is required by pub.dev for publishing.
- Write changelog entries for **external package consumers**, not project committers. Focus on new capabilities, breaking changes, and what consumers can now do. Avoid internal details like dependency moves, refactors, static analysis fixes, or CI changes.
- A change is scoped to a single package wherever possible; cross-package changes should bump each affected package independently.

### Static Analysis
- Run `flutter analyze` before committing to ensure there are no warnings or errors. Clean static analysis is required for smooth pub.dev releases.

### Code Style
- Use `const` constructors where possible
- Prefer stateless widgets; use stateful only when necessary
- Document all public APIs with triple-slash (`///`) comments
- Theme-aware colors via `Theme.of(context).colorScheme`
- Single responsibility: one widget per file; one widget concern per package
- Implementation lives under `lib/src/`; only the public API is re-exported from the barrel

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

## Packages

| Package | Widget | Dependency |
|---|---|---|
| `codifyiq_ai_progress_indicator` | Shimmer progress indicator for AI actions | `shimmer` |
| `codifyiq_audio_message` | Chat-style audio player (pluggable backend) | `just_audio` |
| `codifyiq_brightness_button` | Light/Dark/System theme toggle | `adaptive_theme` |
| `codifyiq_image_viewer` | Full-screen image viewer (swipe, pinch-zoom) | `photo_view` |
| `codifyiq_notification_center` | Play Store-style notification bell + center | — |
| `codifyiq_pdf_viewer` | PDF viewer with zoom + search | `pdfrx` |
| `codifyiq_social_sign_in` | Presentational social sign-in screen | — |
| `codifyiq_terms_and_conditions` | Scrollable T&C with acceptance checkbox | `gpt_markdown` |
| `codifyiq_user_avatar` | Circular avatar with photo/initials/icon fallbacks | — |
