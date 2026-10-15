## 1.0.0

* Initial release.
* `VideoViewerWidget` — an inline video player with play/pause, a scrubber, elapsed and total time, a mute button (plus a volume slider on macOS, Windows, Linux and desktop browsers), and loading, buffering and error states with Retry. It keeps the screen awake while playing, pauses when another screen covers it or its tab is switched away from, jumps back or forward ten seconds on a double tap on phones and tablets, and has a full-screen button that carries on the same video on its own page, in landscape for wide videos on phones and tablets, with `onExitFullScreen` to re-apply your app's own orientation and system UI settings afterwards.
* `VideoViewerScreen` — a full-screen player to push as its own route, with a close button, an optional title, and Share, Download and custom overflow actions placed the same way as `codifyiq_image_viewer` and `codifyiq_pdf_viewer`.
* `VideoThumbnailTile` — a tappable poster with a play badge and optional duration for lists and chat bubbles. It loads no video until you open one.
* `VideoSource` — network URLs (with HTTP headers for authenticated endpoints), local files and bundled assets.
