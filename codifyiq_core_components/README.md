# CodifyIQ Common Components

[![License](https://img.shields.io/github/license/mashape/apistatus.svg)](https://opensource.org/licenses/mit)

**CodifyIQ Common Components** is an open-source Flutter library designed to accelerate mobile and 
web application development by providing reusable, customizable, and production-ready UI components. 
Built with flexibility and performance in mind, this library empowers developers to quickly 
integrate common functionalities into their Flutter projects while maintaining full control over 
customization and long-term maintenance.

This library is developed by [CodifyIQ](https://codifyiq.com) to streamline development workflows, 
reduce boilerplate code, and ensure high-quality, maintainable solutions. The components are 
designed to be modular, extensible, and free from proprietary dependencies, allowing developers to 
adapt and maintain their projects independently.

## Features

- **Reusable UI Components**: Pre-built, customizable widgets to speed up development.
- **Open Source**: Licensed under MIT for maximum flexibility and community contribution.
- **Cross-Platform**: Compatible with Flutter for iOS, Android, web, and desktop applications.
- **Extensible Design**: Built with customization in mind to fit a wide range of use cases.
- **Well-Documented**: Comprehensive documentation and examples for each component.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  codifyiq_common_components: ^0.1.0
  
```

## Widgets

### `TermsAndConditionsWidget`

The `TermsAndConditionsWidget` provides a standardized way to display terms and conditions to users and require them to accept before proceeding. It features:

*   Scrollable Markdown view for the terms.
*   A checkbox for acceptance.
*   The checkbox is enabled only when the content is non-scrollable or the user has scrolled to the very end of the terms.
*   Customizable terms content and an `onAccepted` callback.
*   Defaults to `ipsom lorem` while your legal team works on exact language

### Examples
You can find sample code in the `example` directory as well as more details in the 
[Examples README](./example/README.md) for details.