## 1.0.0

- Initial release.
- Renders `VideoMessage` as a fixed-aspect-ratio thumbnail with a play overlay.
- Supports backend-provided thumbnail URLs via `message.metadata['thumbnailUrl']`.
- Falls back to `video_thumbnail`-generated thumbnails on Android, iOS, and macOS.
- Loading, error, and upload-progress states with customisable builders.
- Duration badge via `message.metadata['duration']`.
- Fully overridable via `customVideoWidget`, `thumbnailBuilder`, `loadingBuilder`,
  `errorBuilder`, and `overlay` parameters.
- Integrates with `flutter_chat_ui` `Builders.videoMessageBuilder`.
