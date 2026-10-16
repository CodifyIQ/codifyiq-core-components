# codifyiq_terms_and_conditions

[![pub package](https://img.shields.io/pub/v/codifyiq_terms_and_conditions.svg)](https://pub.dev/packages/codifyiq_terms_and_conditions)

A standardized way to display terms and conditions and require acceptance before proceeding.

## Demo
Select the image for a quick walkthrough:
[![Watch the terms and conditions widget in action](doc/codifyiq_terms_and_conditions_demo.png)](https://drive.google.com/file/d/1kRGmosRl-_j_X0WegzfaLkRxTzdQYyl3/view?usp=drive_link)

## Features

* Scrollable Markdown view for the terms (rendered with [`gpt_markdown`](https://pub.dev/packages/gpt_markdown)).
* An acceptance button, enabled only once the content is non-scrollable or the user has
  scrolled to the very end.
* Customizable terms content and an `onAccepted` callback; a null callback disables the button.
* Short, overridable button labels (`readPromptLabel`, `acceptLabel`) that stay on one line and
  can be localized.
* An `isProcessing` flag that shows a progress indicator while an acceptance is being recorded.
* An optional `changesSummary` for re-acceptance of a revised document: a "What's changed" card
  with the full terms one tap away, and the button live without scrolling the whole document.
* Defaults to placeholder text while your legal team finalizes the language.

## Installation

```yaml
dependencies:
  codifyiq_terms_and_conditions: ^2.0.0
```

## Usage

```dart
import 'package:codifyiq_terms_and_conditions/codifyiq_terms_and_conditions.dart';

TermsAndConditionsWidget(
  onAccepted: () => Navigator.of(context).pop(true),
);
```

While an acceptance is being recorded server-side, disable the button and show a spinner:

```dart
TermsAndConditionsWidget(
  isProcessing: _isRecording,
  onAccepted: _recordAcceptance,
);
```

Both button labels can be replaced — to localize them, or to use your own assent wording:

```dart
TermsAndConditionsWidget(
  readPromptLabel: 'Lire pour accepter',
  acceptLabel: 'Accepter',
  onAccepted: _recordAcceptance,
);
```

### Re-acceptance of a new version

Someone who already accepted an earlier version should not have to scroll the whole document
again. Pass `changesSummary` to open on a short summary card instead. A "Read the full terms"
action expands the full terms in place beneath it, and the button is enabled straight away while
only the summary shows; once the full terms are expanded the usual scroll-to-end gate applies.

```dart
TermsAndConditionsWidget(
  termsContent: updatedTerms,
  changesSummary: 'We now keep usage logs for 30 days instead of 90.',
  acceptLabel: 'I agree to the updated terms',
  onAccepted: _recordAcceptance,
);
```

This is clickwrap, and it holds up when the full terms are reachable before agreeing (the widget
does that), the summary is accurate (yours), and the button names what is being agreed to. Pass an
explicit `acceptLabel` rather than relying on the default `'Accept'`, and record which version was
accepted alongside the acceptance.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `headerText` | `String` | `'Terms and Conditions'` | Heading shown above the terms. |
| `termsContent` | `String?` | placeholder text | The terms, as Markdown. |
| `onAccepted` | `VoidCallback?` | `null` | Invoked when the user accepts. When `null` the button is disabled. |
| `readPromptLabel` | `String` | `'Read to accept'` | Button label while the terms have not been scrolled to the end. |
| `acceptLabel` | `String` | `'Accept'` | Button label once the terms have been scrolled to the end. |
| `isProcessing` | `bool` | `false` | While `true`, disables the button and replaces its label with a progress indicator. |
| `changesSummary` | `String?` | `null` | Markdown summary of what changed. When set and not blank, opens on a summary card with the full terms one tap away. |
| `changesHeaderText` | `String` | `"What's changed"` | Heading of the summary card. |
| `readFullTermsLabel` | `String` | `'Read the full terms'` | Label of the action that expands the full terms beneath the summary. |

The default labels are short so they stay on one line down to a 360dp-wide screen at a 1.3x
accessibility text scale. If you override them — or support narrower screens — keep them brief;
a long label wraps and makes the button noticeably taller.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)
