import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'video_source.dart';
import 'video_viewer_widget.dart';

/// Callback signature for the Share action of a [VideoViewerScreen].
///
/// [sharePositionOrigin] is the screen-space [Rect] of the share button. Pass
/// it to the `sharePositionOrigin` parameter of `share_plus` (or similar) so
/// the iPad share-sheet popover anchors to the button. The rect is captured
/// before the callback fires, so it is safe to use across an `async` gap. It
/// is `null` on web, where Share sits in the overflow menu.
typedef VideoViewerShareCallback = void Function(Rect? sharePositionOrigin);

/// A consumer-defined entry in the overflow menu of a [VideoViewerScreen].
///
/// Use this for actions beyond the built-in Share and Download, such as
/// "Copy link". Pass a list to [VideoViewerScreen.actions].
class VideoViewerAction {
  /// Creates a [VideoViewerAction].
  ///
  /// [label] is the menu item text, [icon] its leading icon, and
  /// [onSelected] is called when the item is chosen.
  const VideoViewerAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  /// Text shown for the menu item.
  final String label;

  /// Icon shown before [label].
  final IconData icon;

  /// Called when the action is chosen.
  final VoidCallback onSelected;
}

/// A full-screen video player with a close button, a title, and Share and
/// Download actions.
///
/// Push it onto the navigation stack as its own route — for example from a
/// tapped `VideoThumbnailTile` — rather than embedding it in a page; use
/// [VideoViewerWidget] directly for an inline player. It always renders on a
/// black canvas with white controls, regardless of the app's theme.
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     fullscreenDialog: true,
///     builder: (_) => VideoViewerScreen(
///       source: VideoSource.uri(Uri.parse('https://example.com/clip.mp4')),
///       title: 'clip.mp4',
///       onShare: (sharePositionOrigin) => share(sharePositionOrigin),
///       onDownload: download,
///     ),
///   ),
/// );
/// ```
///
/// ## Actions
///
/// Provide [onShare] and/or [onDownload] to enable the corresponding
/// actions; a `null` callback hides its action. The platform's usual one gets
/// an app bar button — Share on mobile and desktop, Download on web — and the
/// other goes in the overflow menu, followed by your own entries from
/// [actions]. The overflow menu is hidden when it would be empty. Sharing and
/// saving are left to the consumer so this package carries no platform
/// plugins beyond the player.
///
/// ## Closing
///
/// The close button pops the route, and is left out when there is no route
/// to go back to. Supply [onClose] when the screen isn't a pushed route — for
/// example a deep-linked page — to show the button and decide where it goes.
class VideoViewerScreen extends StatelessWidget {
  /// Creates a [VideoViewerScreen].
  ///
  /// [source] is the video to play.
  const VideoViewerScreen({
    super.key,
    required this.source,
    this.title,
    this.onClose,
    this.onShare,
    this.onDownload,
    this.actions = const [],
    this.autoPlay = true,
    this.looping = false,
    this.errorBuilder,
    this.errorMessage = 'Could not load video',
    this.onExitFullScreen,
  });

  /// The video to play.
  final VideoSource source;

  /// Title shown in the app bar, typically the file name. Long titles are
  /// truncated with an ellipsis.
  final String? title;

  /// Called when the user taps the close button. If `null`, the button pops
  /// the route, and is hidden when there is no route to go back to.
  final VoidCallback? onClose;

  /// Called when the user chooses Share. If `null`, Share is hidden.
  final VideoViewerShareCallback? onShare;

  /// Called when the user chooses Download. If `null`, Download is hidden.
  final VoidCallback? onDownload;

  /// Additional actions, shown in order at the end of the overflow menu.
  final List<VideoViewerAction> actions;

  /// Whether playback starts as soon as the video has loaded. Defaults to
  /// `true`, since opening the screen is already a request to watch. See
  /// [VideoViewerWidget.autoPlay].
  final bool autoPlay;

  /// Whether the video starts again from the beginning when it ends.
  final bool looping;

  /// Optional builder for an error UI shown in place of the video when it
  /// fails to load.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Message shown by the default error UI.
  final String errorMessage;

  /// Called when the player's own full-screen mode closes. See
  /// [VideoViewerWidget.onExitFullScreen].
  final VoidCallback? onExitFullScreen;

  void _handleClose(BuildContext context) {
    final onClose = this.onClose;
    if (onClose != null) return onClose();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final onShare = this.onShare;
    final onDownload = this.onDownload;
    // Whichever of Share and Download has no app bar button on this platform,
    // then the consumer's own actions.
    final overflow = <(String, IconData, VoidCallback)>[
      if (kIsWeb && onShare != null)
        ('Share', Icons.share_outlined, () => onShare(null)),
      if (!kIsWeb && onDownload != null)
        ('Download', Icons.download_outlined, onDownload),
      for (final action in actions)
        (action.label, action.icon, action.onSelected),
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Like AppBar's own back button, left out when it would do nothing.
        automaticallyImplyLeading: false,
        leading: onClose != null || (ModalRoute.of(context)?.canPop ?? false)
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => _handleClose(context),
              )
            : null,
        title: title == null
            ? null
            : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // Mobile: Share as a visible button. A Builder gives it its own
          // context, so its rect can be read for the iPad share-sheet anchor.
          if (!kIsWeb && onShare != null)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share',
                onPressed: () {
                  final box = context.findRenderObject() as RenderBox?;
                  onShare(
                    box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  );
                },
              ),
            ),
          // Web: Download as a visible button.
          if (kIsWeb && onDownload != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Download',
              onPressed: onDownload,
            ),
          if (overflow.isNotEmpty)
            PopupMenuButton<VoidCallback>(
              tooltip: 'More actions',
              onSelected: (callback) => callback(),
              itemBuilder: (context) => [
                for (final (label, icon, callback) in overflow)
                  PopupMenuItem(
                    value: callback,
                    child: ListTile(
                      leading: Icon(icon),
                      title: Text(label),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
      // Keep the playback controls clear of the notch and home indicator.
      body: SafeArea(
        top: false,
        child: VideoViewerWidget(
          source: source,
          autoPlay: autoPlay,
          looping: looping,
          errorBuilder: errorBuilder,
          errorMessage: errorMessage,
          onExitFullScreen: onExitFullScreen,
        ),
      ),
    );
  }
}
