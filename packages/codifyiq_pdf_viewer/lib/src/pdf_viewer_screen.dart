import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'pdf_source.dart';
import 'pdf_viewer_widget.dart';

/// Callback signature for the Share action of a [PdfViewerScreen].
///
/// [sharePositionOrigin] is the screen-space [Rect] of the share button. Pass
/// it to the `sharePositionOrigin` parameter of `share_plus` (or similar) so
/// the iPad share-sheet popover anchors to the button. The rect is captured
/// before the callback fires, so it is safe to use across an `async` gap. It
/// is `null` on web, where Share sits in the overflow menu.
typedef PdfViewerShareCallback = void Function(Rect? sharePositionOrigin);

/// A consumer-defined entry in the overflow menu of a [PdfViewerScreen].
///
/// Use this for actions beyond the built-in Share and Download, such as
/// "Open in browser". Pass a list to [PdfViewerScreen.actions].
class PdfViewerAction {
  /// Creates a [PdfViewerAction].
  ///
  /// [label] is the menu item text, [icon] its leading icon, and
  /// [onSelected] is called when the item is chosen.
  const PdfViewerAction({
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

/// A full-screen PDF viewer with a close button, a title, and Share,
/// Download and search actions.
///
/// Push it onto the navigation stack as its own route — for example from a
/// tapped chat attachment — rather than embedding it in a page; use
/// [PdfViewerWidget] directly for an inline viewer.
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     fullscreenDialog: true,
///     builder: (_) => PdfViewerScreen(
///       source: PdfSource.uri(Uri.parse('https://example.com/report.pdf')),
///       title: 'report.pdf',
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
/// plugins.
///
/// ## Search
///
/// When [enableSearch] is `true` (the default) the app bar has a search
/// button that shows the viewer's search bar, ready to type in. The button,
/// or the system back gesture, hides it again and clears the current search.
///
/// ## Closing
///
/// The close button pops the route, and is left out when there is no route
/// to go back to. Supply [onClose] when the screen isn't a pushed route — for
/// example a deep-linked page — to show the button and decide where it goes.
class PdfViewerScreen extends StatefulWidget {
  /// Creates a [PdfViewerScreen].
  ///
  /// [source] is the PDF document to display.
  const PdfViewerScreen({
    super.key,
    required this.source,
    this.title,
    this.onClose,
    this.onShare,
    this.onDownload,
    this.actions = const [],
    this.enableSearch = true,
    this.showZoomControlsOnWeb = true,
    this.showPageIndicator = true,
    this.showDownloadProgress = true,
    this.initialPageNumber = 1,
    this.networkTimeout = const Duration(seconds: 30),
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onDownloadProgress,
    this.errorBuilder,
    this.searchDebounce = const Duration(milliseconds: 300),
  }) : assert(minScale > 0 && minScale <= maxScale),
       assert(initialPageNumber >= 1);

  /// The PDF document to render.
  final PdfSource source;

  /// Title shown in the app bar, typically the file name. Long titles are
  /// truncated with an ellipsis.
  final String? title;

  /// Called when the user taps the close button. If `null`, the button pops
  /// the route, and is hidden when there is no route to go back to.
  final VoidCallback? onClose;

  /// Called when the user chooses Share. If `null`, Share is hidden.
  final PdfViewerShareCallback? onShare;

  /// Called when the user chooses Download. If `null`, Download is hidden.
  final VoidCallback? onDownload;

  /// Additional actions, shown in order at the end of the overflow menu.
  final List<PdfViewerAction> actions;

  /// Whether the app bar offers a button that shows and hides the search bar.
  final bool enableSearch;

  /// Whether +/− zoom buttons are shown on web. See
  /// [PdfViewerWidget.showZoomControlsOnWeb].
  final bool showZoomControlsOnWeb;

  /// Whether the "Page X / Y" overlay is shown. See
  /// [PdfViewerWidget.showPageIndicator].
  final bool showPageIndicator;

  /// Whether a progress bar is shown while a network document downloads. See
  /// [PdfViewerWidget.showDownloadProgress].
  final bool showDownloadProgress;

  /// The 1-based page the document opens to. See
  /// [PdfViewerWidget.initialPageNumber].
  final int initialPageNumber;

  /// Time allowed for each network request to start responding. See
  /// [PdfViewerWidget.networkTimeout].
  final Duration networkTimeout;

  /// Lower bound for the zoom level. See [PdfViewerWidget.minScale].
  final double minScale;

  /// Upper bound for the zoom level. See [PdfViewerWidget.maxScale].
  final double maxScale;

  /// Called whenever the visible page changes, with the 1-based page number.
  final ValueChanged<int>? onPageChanged;

  /// Called once the document has loaded, with the total page count.
  final void Function(int pageCount)? onDocumentLoaded;

  /// Called as a network document downloads, with the bytes received and the
  /// total when known. See [PdfViewerWidget.onDownloadProgress].
  final void Function(int received, int? total)? onDownloadProgress;

  /// Optional builder for an error UI shown in place of the document when
  /// loading fails.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Idle time before a typed search query is submitted to the searcher.
  final Duration searchDebounce;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isSearching = false;

  @override
  void didUpdateWidget(covariant PdfViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't reopen the search bar by surprise if search is offered again.
    if (!widget.enableSearch) _isSearching = false;
  }

  // Closes the screen itself, even with the search bar open. Only offered
  // when there is somewhere to go (see build).
  void _handleClose() {
    final onClose = widget.onClose;
    if (onClose != null) return onClose();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final onShare = widget.onShare;
    final onDownload = widget.onDownload;
    // Whichever of Share and Download has no app bar button on this platform,
    // then the consumer's own actions.
    final overflow = <(String, IconData, VoidCallback)>[
      if (kIsWeb && onShare != null)
        ('Share', Icons.share_outlined, () => onShare(null)),
      if (!kIsWeb && onDownload != null)
        ('Download', Icons.download_outlined, onDownload),
      for (final action in widget.actions)
        (action.label, action.icon, action.onSelected),
    ];
    // Back closes the search bar first, and the screen only after that.
    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _isSearching = false);
      },
      child: _buildScaffold(context, title, onShare, onDownload, overflow),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    String? title,
    PdfViewerShareCallback? onShare,
    VoidCallback? onDownload,
    List<(String, IconData, VoidCallback)> overflow,
  ) {
    return Scaffold(
      appBar: AppBar(
        // Like AppBar's own back button, left out when it would do nothing.
        automaticallyImplyLeading: false,
        leading:
            widget.onClose != null || (ModalRoute.of(context)?.canPop ?? false)
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: _handleClose,
              )
            : null,
        title: title == null
            ? null
            : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.enableSearch)
            IconButton(
              icon: Icon(_isSearching ? Icons.search_off : Icons.search),
              tooltip: _isSearching ? 'Close search' : 'Search',
              onPressed: () => setState(() => _isSearching = !_isSearching),
            ),
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
      // Keep the page indicator and zoom buttons clear of the home indicator.
      // The sides stay uninset so the document and search bar run edge to
      // edge in landscape.
      body: SafeArea(
        top: false,
        left: false,
        right: false,
        child: PdfViewerWidget(
          source: widget.source,
          enableSearch: widget.enableSearch && _isSearching,
          autofocusSearch: true,
          showZoomControlsOnWeb: widget.showZoomControlsOnWeb,
          showPageIndicator: widget.showPageIndicator,
          showDownloadProgress: widget.showDownloadProgress,
          onDownloadProgress: widget.onDownloadProgress,
          searchDebounce: widget.searchDebounce,
          initialPageNumber: widget.initialPageNumber,
          networkTimeout: widget.networkTimeout,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          onPageChanged: widget.onPageChanged,
          onDocumentLoaded: widget.onDocumentLoaded,
          errorBuilder: widget.errorBuilder,
        ),
      ),
    );
  }
}
