# codifyiq_video_viewer

[![pub package](https://img.shields.io/pub/v/codifyiq_video_viewer.svg)](https://pub.dev/packages/codifyiq_video_viewer)

A video player for Flutter apps, backed by the first-party
[`video_player`](https://pub.dev/packages/video_player) plugin: an inline player, a full-screen
viewer route, and a lightweight thumbnail tile for lists and chat bubbles.

## Features

* **Inline player** — `VideoViewerWidget` with play/pause, a scrubber, elapsed and total time,
  mute, and a volume slider on desktop and in desktop browsers. Controls hide themselves during
  playback or when you tap elsewhere, and return when the video is tapped. On phones and tablets, double-tap the left or
  right side to jump back or forward ten seconds.
* **Full-screen button** — takes the playing video full screen without restarting it, turning
  wide videos to landscape on phones and tablets.
* **Screen stays awake** while a video plays, and can sleep again once it stops.
* **Full-screen viewer** — `VideoViewerScreen` wraps the player in a route with a close button,
  a title, and optional Share, Download and custom actions.
* **Thumbnail tile** — `VideoThumbnailTile` shows a poster with a play badge and duration. It
  loads no video, so a long list of them stays cheap.
* **A unified `VideoSource`** — network URLs (with HTTP headers), local files and assets.
* **Loading and errors handled** — spinners while loading and buffering, and an error state
  with Retry that you can replace with your own.

## Installation

```yaml
dependencies:
  codifyiq_video_viewer: ^1.0.0
```

Playing network video needs the usual platform setup from
[`video_player`](https://pub.dev/packages/video_player#installation): the `INTERNET` permission
in your Android manifest, and the network client entitlement on macOS.

## Usage

Show a thumbnail, and open the full-screen viewer when it is tapped:

```dart
import 'package:codifyiq_video_viewer/codifyiq_video_viewer.dart';

final source = VideoSource.uri(Uri.parse('https://example.com/clip.mp4'));

VideoThumbnailTile(
  thumbnail: const NetworkImage('https://example.com/clip.jpg'),
  duration: const Duration(seconds: 42),
  onTap: () => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoViewerScreen(source: source, title: 'clip.mp4'),
    ),
  ),
);
```

Or embed the player directly. It fills the space it is given and letterboxes the video, so
give it a size:

```dart
AspectRatio(
  aspectRatio: 16 / 9,
  child: VideoViewerWidget(source: source),
);
```

Load from a local file or a bundled asset with the other `VideoSource` variants:

```dart
VideoViewerWidget(source: VideoSource.file('/path/to/clip.mp4'));
VideoViewerWidget(source: VideoSource.asset('assets/clip.mp4'));
```

`VideoViewerScreen` starts playing as soon as the video loads; `VideoViewerWidget` waits for
the user unless you pass `autoPlay: true`.

A `VideoViewerWidget` pauses when it is hidden: once a full-screen route, such as a
`VideoViewerScreen`, has covered it, or when its tab in an `IndexedStack` or tab scaffold is
switched away from. It stays paused when it is shown again. Dialogs and menus don't pause it,
and nor does its own full-screen button.

### Full screen

The full-screen button in the controls opens the same video on a page of its own and carries
on playing from where it was; closing it, or pressing back, returns the video inline. On phones
and tablets that page hides the status and navigation bars and turns a wide video to landscape.
On web it fills the page.

When the page closes, the system bars come back in edge-to-edge mode and orientation goes back
to what your app declares in `Info.plist` or the Android manifest. Flutter can't read the
current settings to restore them, so if your app sets its own in code, with
`SystemChrome.setPreferredOrientations` or `SystemChrome.setEnabledSystemUIMode`, set them
again in `onExitFullScreen`:

```dart
VideoViewerWidget(
  source: source,
  onExitFullScreen: () => SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]),
);
```

Pass `allowFullScreen: false` to hide the button.

### Actions

```dart
VideoViewerScreen(
  source: source,
  title: 'clip.mp4',
  onShare: (sharePositionOrigin) => shareClip(sharePositionOrigin),
  onDownload: downloadClip,
  actions: [
    VideoViewerAction(
      label: 'Copy link',
      icon: Icons.link,
      onSelected: copyClipLink,
    ),
  ],
);
```

Share and Download appear only when you supply their callbacks, and what they do is up to
you, so the package carries no sharing or file-saving plugins. As in `codifyiq_image_viewer`
and `codifyiq_pdf_viewer`, the platform's usual action gets an app bar button (Share on
mobile and desktop, Download on web) and the other goes in the overflow menu, followed by your
own `actions`. `onShare` receives the Share button's position; pass it as
`sharePositionOrigin` to `share_plus` so the iPad share sheet anchors to the button.

The close button pops the route, and is hidden when there is no route to go back to. If the
screen is not a pushed route (a deep-linked page, for example), pass `onClose` to show the
button and decide where it goes.

## Authentication

For videos behind an authenticated endpoint, pass HTTP headers via `VideoSource.uri`:

```dart
VideoViewerScreen(
  source: VideoSource.uri(
    Uri.parse('https://api.example.com/videos/42.mp4'),
    headers: {'Authorization': 'Bearer $jwt'},
  ),
);
```

Headers are applied when the video loads. If only the headers change while a video is playing
(a refreshed token, for example), playback carries on uninterrupted and the new headers are
used the next time the video loads.

> **Web note:** browsers don't allow custom headers on video requests, so `headers` are
> ignored on web. Use a short-lived signed URL (or cookie authentication) there. The server
> must also send CORS headers, and `VideoSource.file` is not supported on web.

## Serving video

The player streams: it asks the server for byte ranges so it can start quickly and seek
without downloading the whole file. Serve videos from something that answers range requests
with `206 Partial Content` — object storage such as Cloud Storage or S3 does this out of the
box. An endpoint that only returns the whole file will play poorly or not at all on iOS.

## Supported platforms

Android, iOS, macOS and web, as supported by `video_player`. Windows and Linux are not
supported.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)
