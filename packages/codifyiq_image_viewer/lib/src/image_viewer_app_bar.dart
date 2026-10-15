import 'package:material_ui/material_ui.dart';

/// A consumer action as the header shows it, already bound to the visible
/// image.
typedef ImageViewerAppBarAction = ({
  String label,
  IconData icon,
  VoidCallback onPressed,
});

/// Transparent app bar with a close button, title, and action buttons.
///
/// On web: Download is a direct icon button; Share and Delete are in the overflow menu.
/// On mobile: Share is a direct icon button; Download and Delete are in the overflow menu.
/// Consumer actions in [appBarActions] follow as buttons.
class ImageViewerAppBar extends StatelessWidget {
  const ImageViewerAppBar({
    super.key,
    required this.title,
    required this.foregroundColor,
    required this.isWeb,
    this.shareButtonKey,
    this.overflowMenuKey,
    this.onClose,
    this.onShare,
    this.onDownload,
    this.onDelete,
    this.appBarActions = const [],
    this.menuActions = const [],
  });

  final Widget title;
  final Color foregroundColor;
  final bool isWeb;

  /// Consumer actions shown as header buttons.
  final List<ImageViewerAppBarAction> appBarActions;

  /// Consumer actions shown in the overflow menu, above Delete.
  final List<ImageViewerAppBarAction> menuActions;

  /// Key attached to the mobile Share [IconButton] so the parent state can
  /// read its [RenderBox] for the iPad share-sheet anchor rect.
  final GlobalKey? shareButtonKey;

  /// Key attached to the overflow [PopupMenuButton].
  final GlobalKey? overflowMenuKey;

  /// Called when the user taps the close button. The button is left out when
  /// this is `null`.
  final VoidCallback? onClose;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  // Overflow menu is shown when there are items to put in it.
  // Web: Share + custom + Delete. Mobile: Download + custom + Delete.
  bool get _hasOverflow =>
      menuActions.isNotEmpty ||
      (isWeb
          ? (onShare != null || onDelete != null)
          : (onDownload != null || onDelete != null));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: foregroundColor,
      iconTheme: IconThemeData(color: foregroundColor),
      centerTitle: false,
      titleSpacing: 0,
      title: title,
      automaticallyImplyLeading: false,
      leading: onClose == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
            ),
      actions: [
        // Web: Download as a visible icon button in the app bar.
        if (isWeb && onDownload != null)
          IconButton(
            icon: Icon(Icons.download_outlined, color: foregroundColor),
            tooltip: 'Download',
            onPressed: onDownload,
          ),
        // Mobile: Share as a visible icon button in the app bar.
        if (!isWeb && onShare != null)
          IconButton(
            key: shareButtonKey,
            icon: Icon(Icons.share_outlined, color: foregroundColor),
            tooltip: 'Share',
            onPressed: onShare,
          ),
        for (final action in appBarActions)
          IconButton(
            icon: Icon(action.icon, color: foregroundColor),
            tooltip: action.label,
            onPressed: action.onPressed,
          ),
        if (_hasOverflow)
          PopupMenuButton<VoidCallback>(
            key: overflowMenuKey,
            icon: Icon(Icons.more_vert, color: foregroundColor),
            tooltip: 'More actions',
            onSelected: (callback) => callback(),
            itemBuilder: (context) => [
              // Web: Share in overflow.
              if (isWeb && onShare != null)
                PopupMenuItem(
                  value: onShare,
                  child: const ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // Mobile: Download in overflow.
              if (!isWeb && onDownload != null)
                PopupMenuItem(
                  value: onDownload,
                  child: const ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Download'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // Both platforms: consumer-defined actions.
              for (final action in menuActions)
                PopupMenuItem(
                  value: action.onPressed,
                  child: ListTile(
                    leading: Icon(action.icon),
                    title: Text(action.label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // Both platforms: Delete.
              if (onDelete != null)
                PopupMenuItem(
                  value: onDelete,
                  child: const ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
