[[Return to Main Documentation]](../README.md)

## Examples

You can see running examples of the widgets by:
 1. Install the dependencies:
 ```bash
 flutter pub get
 ```
 2. Run the example dart file:
 ```bash
 flutter run -t ./example/main.dart -d chrome
 ```

### `BrightnessButton`
A self contained button to activate a change in brightness (light/dark mode) using the 
[AdaptiveTheme library](https://pub.dev/packages/adaptive_theme).  Please see AdaptiveTheme 
documentation for how to configure it your codebase. Alternatively, see how [main.dart](./main.dart) 
is leveraging this library.  

### `TermsAndConditionsWidget`
Please see [terms_and_conditions_widget_example.dart](./terms_and_conditions_widget_example.dart) 
for usage details around the `TermsAndConditionsWidget`.

### `ErrorRetryWidget`
A widget for displaying a standardized error message with a "Retry" button. This 
is useful for handling network failures or other recoverable errors.

Please see [error_retry_widget_example.dart](./error_retry_widget_example.dart)
for usage details around the `ErrorRetryWidget`.

