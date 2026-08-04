# codifyiq_user_avatar

[![pub package](https://img.shields.io/pub/v/codifyiq_user_avatar.svg)](https://pub.dev/packages/codifyiq_user_avatar)

A circular user avatar with graceful fallbacks: it shows a photo when available, falls back to
the user's initials, and finally to a placeholder icon.

## Demo
Select the image for a quick walkthrough:
[![Watch the user avatar in action](doc/codifyiq_user_avatar_demo.png)](https://drive.google.com/file/d/1CuqSiLByZsKK_tYSO-UuiFwFWUIl3Tes/view?usp=drive_link)

## Installation

```yaml
dependencies:
  codifyiq_user_avatar: ^1.2.0
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

### In-memory and base64 photos

For a photo you already hold as bytes — or, as it usually arrives from an OAuth
provider or JSON API, as a base64 string — pass `photoBytes` or `photoBase64`
instead of a URL. Both take precedence over `photoUrl` and flow through the same
circular clip, cover fit, and initials fallback:

```dart
UserAvatar(photoBytes: user.photoBytes, displayName: user.displayName);
UserAvatar(photoBase64: user.photoBase64, displayName: user.displayName);
```

The widget owns the `MemoryImage` and reuses it whenever the bytes (or the
base64 string) are unchanged, so recreating them inline in `build` — the common
case in a list that rebuilds when any one row changes — never re-decodes the
photo. `photoBase64` also accepts a `data:image/png;base64,…` URI, and an
undecodable string falls back to initials rather than throwing.

For other sources, such as `FileImage` or `AssetImage`, pass an `imageProvider`;
it takes precedence over every other photo source. Providers are compared by
value across rebuilds, including `MemoryImage` bytes, so an inline provider no
longer forces a re-decode either.

### Bulk-selectable list rows

`SelectableAvatarLeading` wraps a `UserAvatar` as a list row's leading control:
tap it, or hover it on desktop, to swap the avatar for a check icon and report
the selection — the Google Contacts pattern for starting a multi-select
without dedicating a whole column to checkboxes up front. It accepts the same
`displayName` / `email` / `photoUrl` / `imageProvider` / `photoBytes` /
`photoBase64` / `radius` as `UserAvatar`, plus `selected` and `onChanged`:

```dart
Row(
  children: [
    SelectableAvatarLeading(
      displayName: user.name,
      selected: selectedIds.contains(user.id),
      onChanged: (checked) => setState(() {
        if (checked) {
          selectedIds.add(user.id);
        } else {
          selectedIds.remove(user.id);
        }
      }),
    ),
    const SizedBox(width: 12),
    Expanded(child: Text(user.name)),
  ],
);
```

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)
