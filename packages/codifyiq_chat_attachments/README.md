# codifyiq_chat_attachments

[![pub package](https://img.shields.io/pub/v/codifyiq_chat_attachments.svg)](https://pub.dev/packages/codifyiq_chat_attachments)

Image, file, video and audio message bubbles for [`flutter_chat_ui`](https://pub.dev/packages/flutter_chat_ui)
that open the CodifyIQ viewers:

* **Images** open [`codifyiq_image_viewer`](https://pub.dev/packages/codifyiq_image_viewer)
  with a Hero, paging through every image in the conversation.
* **PDFs** open [`codifyiq_pdf_viewer`](https://pub.dev/packages/codifyiq_pdf_viewer)'s
  `PdfViewerScreen`. Other files go to a callback.
* **Videos** open [`codifyiq_video_viewer`](https://pub.dev/packages/codifyiq_video_viewer)'s
  `VideoViewerScreen`.
* **Audio** plays in the bubble with [`codifyiq_audio_message`](https://pub.dev/packages/codifyiq_audio_message),
  one message at a time.

Like `flutter_chat_ui`'s own bubbles, they take their colours, shape and text styles from the
`ChatTheme` that `Chat` provides, and show each message's time and status.

Because it brings all the players, this package depends on `photo_view`, `pdfrx`,
`video_player` and `just_audio`, even if you use only some of its builders. Use the viewer
packages directly if you only need one of them.

## Installation

```yaml
dependencies:
  codifyiq_chat_attachments: ^1.0.0
```

## Usage

Hand a `ChatAttachments` to `Chat`'s builders. `apply` adds its image, file and video message
builders to any builders you already have:

```dart
import 'package:codifyiq_chat_attachments/codifyiq_chat_attachments.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

// Owned by the chat screen: create it in initState and dispose it in dispose.
final audio = AudioMessageController();

final attachments = ChatAttachments(
  audioController: audio,
  onShare: (message, sharePositionOrigin) => share(message, sharePositionOrigin),
  onDownload: (message) => download(message),
  onOpenFile: (message) => openWithSystemApp(message as FileMessage),
);

Chat(
  chatController: chatController,
  currentUserId: userId,
  resolveUser: resolveUser,
  builders: attachments.apply(
    Builders(textMessageBuilder: buildTextMessage),
  ),
);
```

To use only some of the bubbles, pass their builders yourself; other message types keep
`flutter_chat_ui`'s defaults:

```dart
builders: Builders(
  imageMessageBuilder: attachments.imageMessageBuilder,
  fileMessageBuilder: attachments.fileMessageBuilder,
),
```

### Sources and authentication

A message's `source` may be:

* a network URL;
* a `blob:` URL on the web, such as the one `image_picker` returns;
* a local file path or `file://` URI outside the web;
* a bundled asset (`assets/...`);
* a `data:` URI, for images, such as a small inline thumbnail.

These are the same sources `flutter_chat_ui`'s own bubbles read. Storage keys such as `gs://`
paths must be turned into URLs first, or loaded with `imageProvider`. For private storage, return
HTTP headers per message:

```dart
ChatAttachments(
  headers: (message) => {'Authorization': 'Bearer $token'},
);
```

Signed URLs (for example from Google Cloud Storage) need no headers; put the signed URL in
`source`.

Network images load through the `CrossCache` that `Chat` provides, as `flutter_chat_ui`'s own
image bubble loads them, so they are kept on disk and downloaded once for the chat and the
viewer. Pass `Chat` a `crossCache` of your own to share it with the rest of your app. Outside a
`Chat` they load with a `NetworkImage`. To load them another way, supply your own providers:

```dart
ChatAttachments(
  imageProvider: (message) => MyImageProvider(message.source),
  imageThumbnail: (message) => MyImageProvider(thumbnailUrlOf(message)),
);
```

### Images

The bubble takes its shape from the message's `width` and `height`, so the chat does not jump
as images load, and shows the message's `text` as a caption. Without a size it uses the shape of
the message's `thumbhash`, or 4:3, until the image loads and gives its own. A `thumbhash` is also
shown, blurred, until the image arrives.

Set `imageOverlay` to cover images whose message has `hasOverlay`, for example with a blur over
sensitive content, and `imageErrorBuilder` to replace the broken-image icon.

Give an image a thumbnail and the chat loads only that; the full image downloads when the bubble
is tapped, with the thumbnail standing in until it arrives:

```dart
Message.image(
  ...,
  source: fullUrl,
  metadata: {ChatAttachmentMetadata.thumbnail: thumbnailUrl},
);
```

Or return one from `imageThumbnail`. Without a thumbnail, the bubble downloads the full image
but decodes it no larger than the bubble, to save memory. Opening it reuses that download from
the cache.

Tapping it opens the viewer on every image message in the conversation, read from the
`ChatController` that `Chat` provides. Show just the one image instead with
`imageGallery: ChatImageGallery.message`.

### Files

PDFs (by MIME type or a `.pdf` name) open in the PDF viewer. Other files call `onOpenFile`, and
are not tappable without it. `fileIcon` picks an icon per message, for example for spreadsheets.

### Videos

`VideoMessage` has no field for a poster or a length, so put them in its metadata:

```dart
Message.video(
  ...,
  metadata: {
    ChatAttachmentMetadata.thumbnail: posterUrl,
    ChatAttachmentMetadata.durationMs: 65000,
  },
);
```

Or return them from `videoThumbnail` and `videoDuration`.

### Audio

Audio messages play in their bubble, showing the message's `duration` until the clip loads.
Pass `audioController`, an `AudioMessageController` the chat screen creates and disposes: then
starting one message stops the one that was playing, and a message keeps playing when its bubble
scrolls out of view. Without it, each bubble plays on its own and stops when it is disposed.

## Taps and gestures

Tapping an image, PDF or video opens it. Long presses and double taps still reach `Chat`'s
`onMessageLongPress` and `onMessageDoubleTap`, for example for a context menu or reactions.

To handle taps yourself, for example to select messages or retry failed ones, set
`openOnTap: false`: the bubbles then leave taps to `Chat`'s `onMessageTap`, and you can open an
attachment with `openImage`, `openPdf` or `openVideo`:

```dart
Chat(
  onMessageTap: (context, message, {required index, details}) => switch (message) {
    _ when isSelecting => toggleSelection(message),
    final ImageMessage image => attachments.openImage(context, image),
    _ => null,
  },
  ...
);
```

## Appearance

* **Time and status:** `showTime`, `showStatus` and `timeAndStatusPosition`, as on
  `flutter_chat_ui`'s text bubbles, using `Chat`'s `timeFormat`. They sit below the picture, on a
  line of their own at the start or end, or with `TimeAndStatusPosition.inline` beside the
  caption.
* **`topWidget`:** a widget above the attachment, built per message, such as the author's name
  in a group chat or a preview of the message it replies to.
* **Size and shape:** `maxWidth`, `maxHeight` for images and videos, and `borderRadius`, which
  defaults to the `ChatTheme`'s shape.
* **`labels`:** the text the bubbles show or announce, for localisation.

## Viewers

* **`actions`:** your own `ChatAttachmentAction`s in each viewer's overflow menu, called with the
  message being viewed. `isVisible` limits one to some messages, for example only PDFs.
* **`routeBuilder`:** the route a viewer opens in, for a different transition or a route of your
  own. By default it is a full-screen-dialog `MaterialPageRoute` on the root navigator
  (`useRootNavigator`).

## Sending attachments

The bubbles rely on fields that `flutter_chat_core` leaves optional. Fill them in when you create
a message:

| Message | Fields | What they do |
|---|---|---|
| Image | `width`, `height` | Shape the bubble before the image loads |
| Image | `text` | Caption |
| Image | `metadata[thumbnail]` | Loaded in the chat instead of the full image |
| Image | `thumbhash` | Blurred placeholder, and shape until the image loads when the size is missing |
| File | `name`, `size` | Name, type and size in the bubble |
| File | `mimeType` | Recognises a PDF without a `.pdf` name |
| Video | `width`, `height`, `name` | Shape of the tile, and the viewer's title |
| Video | `text` | Caption |
| Video | `metadata[thumbnail]`, `metadata[durationMs]` | Poster and length on the tile |
| Audio | `duration`, `text` | Length before the clip loads, and caption |

Show a message as soon as the user sends it, before it has uploaded:

1. Insert it with the picked file's local path (a `blob:` URL on the web) as `source`, any
   caption the user typed as `text`, and `status: MessageStatus.sending`. The bubble shows the file, dimmed, with a progress ring (a
   progress bar for audio).
2. Report the upload's progress with `updateUploadProgress(message.id, fraction)` on a chat
   controller with `UploadProgressMixin`, such as `InMemoryChatController`. Without it, the ring
   spins.
3. When the upload finishes, update the message, keeping its `id`, with the stored file's URL as
   `source` and a sent status. If it fails, set `failedAt` (or `status: MessageStatus.error`)
   and the bubble is marked as not sent.

Thumbnails are best made where the files are stored, for example by a Cloud Function or the
Resize Images extension writing a small copy next to each upload in Cloud Storage.

### Your own builders

`ChatImageAttachment`, `ChatFileAttachment`, `ChatVideoAttachment` and `ChatAudioAttachment`
are the bubbles on their own, and `openImage`, `openPdf` and `openVideo` push the viewers, so
you can mix them into a builder of your own.

> **Web note:** sources are always loaded as URLs on the web, and the video and audio players
> ignore HTTP headers there.

---

Part of the [CodifyIQ component family](https://github.com/CodifyIQ/codifyiq-core-components) · [pub.dev/publishers/codifyiq.com](https://pub.dev/publishers/codifyiq.com)
