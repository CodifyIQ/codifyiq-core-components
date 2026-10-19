## 1.0.0

* Initial release.
* `ChatAttachments` — image, file, video and audio message builders for `flutter_chat_ui`. Hand them to `Builders` with `apply`, or one at a time. Share and Download in the viewers call back with the message they belong to, and HTTP headers can be set per message for private storage.
* Sources can be network URLs, `blob:` URLs on the web, and local paths or `file://` URIs elsewhere, plus bundled assets (`assets/...`) and `data:` URIs for images — the same as `flutter_chat_ui`'s own bubbles.
* Images open `codifyiq_image_viewer` with a Hero, paging through every image in the conversation (or only the one tapped, with `ChatImageGallery.message`).
* PDFs open `codifyiq_pdf_viewer`'s `PdfViewerScreen`; other files call `onOpenFile`.
* Videos open `codifyiq_video_viewer`'s `VideoViewerScreen`, with an optional poster and duration on the bubble.
* Thumbnails: an image with a thumbnail (`ChatAttachmentMetadata.thumbnail` in its metadata, or `imageThumbnail`) loads only that in the chat, and the viewer shows it until the full image arrives. Without one, the full image is decoded no larger than the bubble, and opening it reuses the download. Network images are cached on disk through the `CrossCache` that `Chat` provides, like `flutter_chat_ui`'s own image bubble. Videos read their poster and length from the metadata too.
* Messages that are sending are dimmed with a progress ring that follows `updateUploadProgress` on the chat controller, and messages that failed to send are marked.
* Audio messages play in their bubble with `codifyiq_audio_message`, showing their length before loading. Share one `audioController` across the chat so one message plays at a time and keeps playing when its bubble scrolls out of view.
* Bubbles take their colours, shape and text styles from `flutter_chat_ui`'s `ChatTheme`, and show the message's time and status below the picture or file, on a line of their own or beside the caption (`showTime`, `showStatus`, `timeAndStatusPosition`), like `flutter_chat_ui`'s own bubbles.
* `openOnTap: false` leaves taps to `Chat`'s `onMessageTap`, for selection or retrying failed messages; `openImage`, `openPdf` and `openVideo` open attachments yourself. Long presses and double taps reach `Chat` either way.
* Images show their `thumbhash` as a blurred placeholder, take its rough shape when the message has no size until the image loads and gives its own, fade in, and show `imageOverlay` when the message has `hasOverlay`. `imageErrorBuilder` replaces the broken-image icon.
* `topWidget` adds a widget above any bubble, such as the author's name; `fileIcon` picks file icons; `maxHeight` and `borderRadius` size and shape the bubbles; `labels` localises the text they show and announce.
* `actions` adds your own entries to the viewers' menus, and `routeBuilder` sets the route the viewers open in.
* `ChatImageAttachment`, `ChatFileAttachment`, `ChatVideoAttachment` and `ChatAudioAttachment` — the bubbles on their own, for custom builders.
