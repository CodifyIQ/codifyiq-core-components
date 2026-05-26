# codifyiq_user_avatar

[![pub package](https://img.shields.io/pub/v/codifyiq_user_avatar.svg)](https://pub.dev/packages/codifyiq_user_avatar)

A circular user avatar with graceful fallbacks: it shows a photo when available, falls back to
the user's initials, and finally to a placeholder icon.

## Installation

```yaml
dependencies:
  codifyiq_user_avatar: ^1.0.0
```

## Usage

```dart
import 'package:codifyiq_user_avatar/codifyiq_user_avatar.dart';

UserAvatar(
  photoUrl: user.photoUrl,
  displayName: user.displayName,
  radius: 24,
);
```

### Non-URL image sources

To use an image you already hold in memory or on disk (not a URL), pass an
`imageProvider`. It takes precedence over `photoUrl`/`imageProviderBuilder` and
flows through the same circular clip, cover fit, and initials fallback:

```dart
UserAvatar(imageProvider: MemoryImage(bytes), displayName: user.displayName);
```

In list contexts, hold a stable `MemoryImage` instance (it compares bytes by
identity) so the image cache can dedupe it across rebuilds.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)
