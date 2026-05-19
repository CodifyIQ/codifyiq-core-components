# Changelog

## 0.7.0
* New widget: `AiChatScreen` — an embeddable AI chat experience built on top of the Flyer Chat packages (`flutter_chat_ui` + `flutter_chat_types`) and re-skinned to the Material 3 theme
  * Scrollable chat timeline with text messaging, multiline input, auto-scroll to the latest message, and a send button that stays visible but grayed out while the input is empty or a reply is in flight
  * Sending is blocked while the assistant is responding — the in-flight request is left to finish and the user's draft text is kept rather than cleared
  * AI replies render as Markdown (headings, bold, lists, code blocks, links) via `gpt_markdown`; user messages render as plain text
  * On wide (desktop) viewports the conversation is centered in a max-width column with dimmed side gutters — tune or disable it with the `maxContentWidth` parameter
  * `AiChatController` manages the message timeline and the backend round-trip — supply your own request logic through its `responder` callback (the package ships no networking layer)
  * Shows an `AiProgressIndicator` while awaiting a reply and an error bubble when a request fails
  * Automatically stamps each message's `seenAt` timestamp the first time it scrolls into view
  * `onSendMessage` and `onMessageTap` callbacks — `onMessageTap` is the integration point for future PDF/image viewers
  * `CodifyChatMessage` model supports text, image, and pdf content plus sender and `seenAt`
  * Image messages render inline through Flyer Chat — set `CodifyChatMessage.sourceUri` to a network or local image and it appears in the timeline with tap-to-zoom; set `enableImageGallery` to `false` to route image taps to `onMessageTap` for a custom viewer instead
  * PDF messages render as tappable Flyer Chat file rows (document icon, name, and `fileSizeBytes` as the subtitle) — handle `onMessageTap` to open your own PDF viewer; the chat widget itself pulls in no PDF rendering library
  * A `+` attachment button opens an "Add image / Add PDF" menu — wire `onAttachImage` / `onAttachPdf` to your own file picker; the button is hidden when neither is provided
* New widget set: `NotificationBellButton`, `NotificationCenterPanel`, `NotificationCenterPage`, and `NotificationCenterController` — a Play Store-style notification center for tracking long-running, user-initiated tasks
  * App-bar bell with a stoplight-coded Material 3 badge — amber while work is in flight, green when every tracked item completed, and red when at least one item failed (failure always wins so a regression is never hidden behind an in-progress indicator)
  * Bell icon swaps to a filled variant whenever items are tracked, so state is conveyed by shape as well as color (WCAG 1.4.1)
  * Badge label rules:
    * **running** → amber dot, never a count (running is ambient state — the count isn't actionable)
    * **success** → green count of unseen successes (always homogeneous: success only wins when no running and no unseen errors)
    * **error** → red count of unseen failures, or a red `!` glyph when an unseen failure coexists with running work
  * Quiet semantics: success and error are notification events that quiet once the user opens the panel; running stays lit while work is in flight even after the user has peeked. A later transition (e.g. running → error) re-lights the bell
  * `runningColor`, `successColor`, `errorColor`, and `activeIcon` overrides on `NotificationBellButton` for tuning the stoplight palette and the active-state glyph; the badge text color is auto-paired to the background luminance so overrides stay legible
  * Opens an anchored dropdown panel on tap
  * Items are grouped into **In progress**, **Failed**, and **Completed** sections with linear progress bars on running rows and status icons on finished rows
  * Per-item tap callback and optional labeled trailing action (e.g. "Open", "Retry") for completed rows
  * Individual dismiss plus "Clear completed" bulk action; running items persist until explicitly completed or failed
  * Adaptive presentation — opens an anchored dropdown on wide viewports and pushes a full-screen `NotificationCenterPage` (with back button) on narrow/mobile viewports (configurable breakpoint, default 600px)
  * Optional `NotificationCenterScope` `InheritedNotifier` exposes the controller ambiently so any descendant widget can post updates without prop-drilling
  * UI-only: consumers wire the controller to their own task layer (HTTP, isolates, platform background workers, etc.)
* `BrightnessButton` now renders its dropdown as a Material 3 surface (rounded corners, elevation, surface tint) and accepts `menuAlignmentOffset` / `menuScreenEdgeInset` to control drop distance and the gap from the trailing viewport edge — matching the new `NotificationBellButton` styling
* New widget: `PdfViewerWidget` — a reusable PDF viewer backed by `pdfrx`
  * Render a PDF from any `PdfSource`: network `Uri`, local file path, or in-memory `Uint8List`
  * Pinch-to-zoom on mobile; Ctrl/Cmd + scroll-wheel and on-screen +/− buttons on web
  * Configurable `minScale` / `maxScale` zoom bounds — the supplied `minScale` is now honored as a literal lower bound (previously could be overridden by an internal fit-page calculation, which also produced a transient assertion on wide viewports during the first frame)
  * Optional in-document text search with debounced input, highlighted matches, next/previous navigation, and a match counter — toggling `enableSearch` off clears any active query and removes in-page match highlights
  * `PdfSource.uri` now accepts optional HTTP `headers`, forwarded to the underlying request — load PDFs from endpoints that require authentication/authorization (e.g. a JWT bearer token)
  * Swapping the `source` at runtime now resets viewer state (page indicator, search input, match highlights) and rebinds the text searcher to the new document instead of carrying the previous document's state forward
  * `PdfSource` variants (`PdfUriSource`, `PdfFileSource`, `PdfBytesSource`) now implement value equality, so two sources describing the same document compare equal
  * Optional page indicator overlay
  * Page change and document-loaded callbacks, plus a customizable error builder
* Added `pdfrx ^2.3.3` dependency — required to render PDF documents
* **Breaking:** minimum SDK requirements raised to Dart `^3.10.0` and Flutter `>=3.41.0` to satisfy `pdfrx`
* New widget: `ImageViewerWidget` — full-screen image viewer foundation
  * Displays images from asset, network, or local file sources (with custom
    `ImageProvider` support for memory, cached, or third-party providers)
  * Horizontal swipe between images, pinch / scroll-wheel zoom, drag pan,
    and animated double-tap zoom centered on the tap point
  * Swipe-between-pages is automatically disabled while an image is zoomed
    so pan gestures don't turn the page
  * Built-in Share, Download, and Delete menu items wired to consumer
    callbacks; menu items hide individually (and the menu hides entirely)
    when their callback is null
  * Customizable loading and error placeholders, page indicator format, and
    background/foreground colors; optional `Hero` tags per image
  * Responsive layout suitable for mobile, tablet, and desktop
* New widget: `SocialSignInScreen` — customizable sign-in screen with logo, tagline, social buttons, error display, and footer
  * Optional reviewer login easter egg for app store submissions — tap the logo to reveal an email/password form for reviewers
  * Built-in processing state replaces sign-in buttons with a progress indicator during authentication, preventing duplicate taps
* New widget: `SocialSignInButton` — consistent button styling for social sign-in providers

## 0.6.0
* New widget: `AiProgressIndicator` — a subtle shimmer progress indicator to visually communicate that an AI-enabled feature is being executed
  * Configurable shimmer sweep speed and brightness-aware color intensity
  * Optional background color for increased visibility
  * Optional ability to hide the circular progress indicator for a text-only shimmer
  * Theme-derived colors by default, with full customization support via `Theme`/`ColorScheme` or `textStyle`
* Added package barrel file — import all widgets with `import 'package:codifyiq_core_components/codifyiq_core_components.dart'`
* Reduced transitive dependency footprint for consumers

## 0.5.0 
* Fixed static analysis warning

## 0.4.0 
* Added `BrightnessButton`
* Refactored examples to work with light/dark mode

## 0.3.0
* Update terms and conditions widget for more consistent formatting

## 0.2.0
* Added basic retry widget
* Added demo page for previewing the widgets

## 0.1.2
* Continuing to refine cleanup and publishing

## 0.1.1
* Cleanup activities; changed Markdown flavor to be `gpt_markdown`

## 0.1.0
* Initial release of a generic terms and conditions widget
