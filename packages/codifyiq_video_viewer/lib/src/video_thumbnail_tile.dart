import 'package:material_ui/material_ui.dart';

import 'video_duration.dart';

/// A tappable video thumbnail with a play badge and an optional duration.
///
/// Use it wherever a video is offered but not yet playing — a chat bubble, a
/// list row, a gallery — and open a `VideoViewerScreen` from [onTap]. It
/// loads no video, so many can sit in a scrolling list cheaply.
///
/// ```dart
/// VideoThumbnailTile(
///   thumbnail: NetworkImage('https://example.com/clip.jpg'),
///   duration: const Duration(seconds: 42),
///   onTap: openClip,
/// )
/// ```
class VideoThumbnailTile extends StatelessWidget {
  /// Creates a [VideoThumbnailTile].
  ///
  /// [thumbnail] is the poster image; without one the tile shows a plain dark
  /// background behind the play badge.
  const VideoThumbnailTile({
    super.key,
    this.thumbnail,
    this.duration,
    this.onTap,
    this.aspectRatio = 16 / 9,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.semanticLabel,
  });

  /// The poster image shown behind the play badge.
  final ImageProvider? thumbnail;

  /// The video's length, shown in the bottom-right corner when set.
  final Duration? duration;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Width divided by height of the tile. Defaults to 16:9.
  final double aspectRatio;

  /// Corner rounding of the tile.
  final BorderRadius borderRadius;

  /// What screen readers announce for the tile, for example a localised
  /// "Play video". Defaults to "Play video" when [onTap] is set and "Video"
  /// otherwise.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final thumbnail = this.thumbnail;
    final duration = this.duration;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Material(
        // Shows when there is no poster; the badges sit on a dark scrim so
        // they read over any poster.
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnail != null)
              Ink.image(
                image: thumbnail,
                fit: BoxFit.cover,
                // A missing poster shouldn't break the tile.
                onImageError: (_, _) {},
              ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            if (duration != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    formatVideoDuration(duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            Semantics(
              button: onTap != null,
              label: semanticLabel ?? (onTap != null ? 'Play video' : 'Video'),
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}
