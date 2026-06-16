# CodifyIQ Components

A family of small, focused, production-ready Flutter widgets — each published as its own package so you only pull the dependencies you actually use.

[![Maintained with Melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg)](https://github.com/invertase/melos)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![pub.dev publisher](https://img.shields.io/badge/pub.dev-codifyiq.com-blue.svg)](https://pub.dev/publishers/codifyiq.com)

---

## About

**CodifyIQ Components** is an open-source collection of reusable, customizable Flutter widgets
maintained by [CodifyIQ](https://codifyiq.com). Each widget ships as a **standalone pub.dev
package** under the verified [`codifyiq.com`](https://pub.dev/publishers/codifyiq.com) publisher.

The packages live together in this monorepo (managed with [Melos](https://melos.invertase.dev))
but publish independently. **Depend on a widget and you get its dependencies; nothing more.**

## Packages

| Package | pub.dev | Android | iOS | Web | macOS | Windows |
|---|---|:-:|:-:|:-:|:-:|:-:|
| [codifyiq_ai_progress_indicator](packages/codifyiq_ai_progress_indicator) | [![pub](https://img.shields.io/pub/v/codifyiq_ai_progress_indicator.svg)](https://pub.dev/packages/codifyiq_ai_progress_indicator) | ✔ | ✔ | ✔ | ✔ | ✔ |
| [codifyiq_audio_message](packages/codifyiq_audio_message) | [![pub](https://img.shields.io/pub/v/codifyiq_audio_message.svg)](https://pub.dev/packages/codifyiq_audio_message) | ✔ | ✔ | ✔ | ✔ | ✔ |
| [codifyiq_brightness_button](packages/codifyiq_brightness_button) | [![pub](https://img.shields.io/pub/v/codifyiq_brightness_button.svg)](https://pub.dev/packages/codifyiq_brightness_button) | ✔ | ✔ | ✔ | ✔ | ✔ |
| [codifyiq_group_manager](packages/codifyiq_group_manager) | [![pub](https://img.shields.io/pub/v/codifyiq_group_manager.svg)](https://pub.dev/packages/codifyiq_group_manager) | ✔ | ✔ | ✔ | ✔ | ✔ |
| [codifyiq_image_viewer](packages/codifyiq_image_viewer) | [![pub](https://img.shields.io/pub/v/codifyiq_image_viewer.svg)](https://pub.dev/packages/codifyiq_image_viewer) | ✔ | ✔ | ✔ ¹ | ✔ | ✔ |
| [codifyiq_notification_center](packages/codifyiq_notification_center) | [![pub](https://img.shields.io/pub/v/codifyiq_notification_center.svg)](https://pub.dev/packages/codifyiq_notification_center) | ✔ | ✔ | ✔ | ✔ | ✔ |
| [codifyiq_pdf_viewer](packages/codifyiq_pdf_viewer) | [![pub](https://img.shields.io/pub/v/codifyiq_pdf_viewer.svg)](https://pub.dev/packages/codifyiq_pdf_viewer) | ✔ | ✔ | ✔ ² | ✔ | ✔ |
| [codifyiq_social_sign_in](packages/codifyiq_social_sign_in) | [![pub](https://img.shields.io/pub/v/codifyiq_social_sign_in.svg)](https://pub.dev/packages/codifyiq_social_sign_in) | ✔ | ✔ | ✔ | ✔ | ✔ |
| [codifyiq_terms_and_conditions](packages/codifyiq_terms_and_conditions) | [![pub](https://img.shields.io/pub/v/codifyiq_terms_and_conditions.svg)](https://pub.dev/packages/codifyiq_terms_and_conditions) | ✔ | ✔ | ✔ | ✔ | ✔ |
| [codifyiq_user_avatar](packages/codifyiq_user_avatar) | [![pub](https://img.shields.io/pub/v/codifyiq_user_avatar.svg)](https://pub.dev/packages/codifyiq_user_avatar) | ✔ | ✔ | ✔ | ✔ | ✔ |

> ¹ `ImageViewerItem.file` is unsupported on Flutter web; use `.network`, `.asset`, or a custom `ImageProvider`.
> ² PDFs loaded via `PdfSource.uri` require CORS headers; `PdfSource.file` is unsupported on web.

## Development

This is a [Melos](https://melos.invertase.dev) workspace using native Dart pub workspaces.

```bash
dart pub global activate melos   # once
melos bootstrap                  # resolve all packages
melos run analyze                # analyze every package
melos run test                   # test every package with a test/ dir
flutter run -t example/lib/main.dart -d chrome   # run the demo catalog
```

The `example/` app demonstrates every widget in a single GoRouter-based catalog.

## Contributing

Issues and pull requests are welcome at
[CodifyIQ/codifyiq-core-components](https://github.com/CodifyIQ/codifyiq-core-components/issues).
Please follow the commit and documentation conventions in [`CLAUDE.md`](CLAUDE.md).

## License

[MIT](LICENSE) © CodifyIQ
