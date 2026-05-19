import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/photo_view.dart';

import '_image_viewer_file_io.dart'
    if (dart.library.html) '_image_viewer_file_web.dart'
    as file_loader;

/// Describes a single image shown by an [ImageViewerWidget].
///
/// Use a named constructor to wrap a common source:
///
/// * [ImageViewerItem.asset]   — bundled asset images.
/// * [ImageViewerItem.network] — images loaded over HTTP(S).
/// * [ImageViewerItem.file]    — images on the local file system (not
///   available on Flutter web).
///
/// Or use the default constructor with any [ImageProvider] for custom sources
/// such as [MemoryImage] or a third-party cached provider.
class ImageViewerItem {
  /// Creates an [ImageViewerItem] from a raw [ImageProvider].
  ///
  /// [provider] is the image source.
  /// [title] is an optional caption available to consuming code (forwarded to
  /// action callbacks; not rendered directly by [ImageViewerWidget]).
  /// [heroTag] enables a [Hero] transition into the viewer from a matching
  /// thumbnail.
  const ImageViewerItem({
    required this.provider,
    this.title,
    this.heroTag,
  });

  /// Loads an image from the app's asset bundle.
  factory ImageViewerItem.asset(
    String name, {
    String? package,
    String? title,
    Object? heroTag,
  }) => ImageViewerItem(
    provider: AssetImage(name, package: package),
    title: title,
    heroTag: heroTag,
  );

  /// Loads an image from a network URL.
  factory ImageViewerItem.network(
    String url, {
    Map<String, String>? headers,
    String? title,
    Object? heroTag,
  }) => ImageViewerItem(
    provider: NetworkImage(url, headers: headers),
    title: title,
    heroTag: heroTag,
  );

  /// Loads an image from a file on the local device.
  ///
  /// Not supported on Flutter web — calling this on a web target throws
  /// [UnsupportedError] when the image is loaded. Use [ImageViewerItem.network]
  /// or [ImageViewerItem.asset] on web instead.
  factory ImageViewerItem.file(
    String path, {
    String? title,
    Object? heroTag,
  }) => ImageViewerItem(
    provider: file_loader.fileImageProvider(path),
    title: title,
    heroTag: heroTag,
  );

  /// The underlying [ImageProvider] used to load this image.
  final ImageProvider provider;

  /// Optional human-readable title for the image.
  ///
  /// Forwarded to action callbacks so consumers can label share/download
  /// flows without looking the title up again.
  final String? title;

  /// Optional tag for a [Hero] transition from a thumbnail into the viewer.
  ///
  /// When set, the corresponding page wraps its image in a [Hero] widget so
  /// callers can animate from a thumbnail by giving that thumbnail a [Hero]
  /// with the same tag.
  ///
  /// The [Hero] is only activated on the page that is currently visible
  /// ([ImageViewerWidget] tracks this internally). Adjacent pages preloaded by
  /// the gallery do not receive a Hero, so the transition always reflects the
  /// photo actually on screen at the moment the route is pushed or popped.
  final Object? heroTag;

}

/// Callback signature for the viewer's action menu items.
///
/// [item] is the [ImageViewerItem] visible when the action was invoked and
/// [index] is its position within the original `items` list.
typedef ImageViewerActionCallback =
    void Function(ImageViewerItem item, int index);

/// Callback signature for the Share action.
///
/// Like [ImageViewerActionCallback] but includes [sharePositionOrigin], the
/// screen-space [Rect] of the share button. Pass this directly to the
/// `sharePositionOrigin` parameter of `share_plus` (or similar) so the iPad
/// share-sheet popover anchors to the correct button. The rect is captured
/// synchronously before the callback fires, so it is safe to use across any
/// subsequent `async` gap.
typedef ImageViewerShareCallback =
    void Function(ImageViewerItem item, int index, Rect? sharePositionOrigin);

/// A modern, full-screen image viewer with swipe navigation, pinch zoom & pan,
/// and an overflow menu for Share / Download / Delete actions.
///
/// This widget is designed to be pushed onto the navigation stack as its own
/// route — for example via [Navigator.push] or a `GoRoute` — because it
/// renders a full-bleed [Scaffold] with a transparent app bar over a dark
/// canvas.
///
/// Powered by `photo_view` ([PhotoViewGallery]) for zoom, pan, and swipe.
/// `photo_view` automatically prevents page-swipe while the current image is
/// zoomed in, so no manual physics management is required.
///
/// ## Image sources
///
/// Images are described by a list of [ImageViewerItem]s. Each item can come
/// from an asset bundle, a network URL, a local file (mobile/desktop only),
/// or any custom [ImageProvider].
///
/// ## Gestures (handled by [PhotoViewGallery])
///
/// * **Horizontal swipe** — moves between images. Disabled automatically
///   while the current image is zoomed in.
/// * **Pinch / scroll wheel** — zooms in and out between [minScale] and
///   [maxScale] relative to the fit-to-screen scale.
/// * **Drag** — pans a zoomed image.
/// * **Double-tap** — cycles between fit-to-screen and zoomed-in states.
///
/// ## Actions
///
/// Provide [onShare], [onDownload], and/or [onDelete] to enable the
/// corresponding menu items. Menu items with `null` callbacks are hidden; if
/// all three are `null` the overflow menu itself is hidden.
///
/// ## Foundation
///
/// This widget is intentionally minimal — a clean, expandable foundation.
/// Loading and error placeholders are customisable via [loadingBuilder] and
/// [errorBuilder], and the title in the app bar via [pageIndicatorBuilder].
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => ImageViewerWidget(
///       items: [
///         ImageViewerItem.network('https://example.com/a.jpg'),
///         ImageViewerItem.network('https://example.com/b.jpg'),
///       ],
///       onShare: (item, index) => share(item),
///     ),
///   ),
/// );
/// ```
class ImageViewerWidget extends StatefulWidget {
  /// Creates an [ImageViewerWidget].
  ///
  /// [items] is the non-empty list of images to display.
  /// [initialIndex] is the page shown when the viewer opens (clamped into
  /// the valid range).
  const ImageViewerWidget({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.backgroundColor = Colors.black,
    this.foregroundColor = Colors.white,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.onShare,
    this.onDownload,
    this.onDelete,
    this.onPageChanged,
    this.pageIndicatorBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.errorMessage = 'Unable to load image',
  }) : assert(items.length > 0, 'items must contain at least one image');

  /// The images to display, in the order they should appear.
  final List<ImageViewerItem> items;

  /// Index of the first image to show. Clamped to `[0, items.length - 1]`.
  final int initialIndex;

  /// Background color of the viewer. Defaults to [Colors.black] so images
  /// pop against the canvas regardless of theme.
  final Color backgroundColor;

  /// Color used for the app bar icons and text. Defaults to [Colors.white].
  final Color foregroundColor;

  /// Minimum zoom, expressed as a factor of the fit-to-screen (contained)
  /// scale. `1.0` means the image cannot be shrunk below the viewport-fitted
  /// size. Defaults to `1.0`.
  final double minScale;

  /// Maximum zoom, expressed as a factor of the fit-to-screen (contained)
  /// scale. `4.0` means the image can be enlarged to four times its fitted
  /// size. Defaults to `4.0`.
  final double maxScale;

  /// Called when the user selects "Share" from the menu. If `null`, the
  /// Share menu item is hidden.
  ///
  /// The third argument, [sharePositionOrigin], is the screen-space bounding
  /// rect of the share button captured before the callback fires. Pass it to
  /// `Share.share(..., sharePositionOrigin: sharePositionOrigin)` so the iPad
  /// share-sheet popover anchors to the correct button.
  final ImageViewerShareCallback? onShare;

  /// Called when the user selects "Download" from the menu. If `null`, the
  /// Download menu item is hidden.
  final ImageViewerActionCallback? onDownload;

  /// Called when the user selects "Delete" from the menu. If `null`, the
  /// Delete menu item is hidden.
  final ImageViewerActionCallback? onDelete;

  /// Called whenever the visible page changes, with the new zero-based index.
  final ValueChanged<int>? onPageChanged;

  /// Builds the title displayed in the app bar.
  ///
  /// Receives the zero-based [currentIndex] and the [total] image count and
  /// must return the string to display. Defaults to `"<index+1> / <total>"`.
  final String Function(int currentIndex, int total)? pageIndicatorBuilder;

  /// Builds the placeholder shown while an image is loading.
  ///
  /// Defaults to a centered [CircularProgressIndicator] tinted with
  /// [foregroundColor].
  final WidgetBuilder? loadingBuilder;

  /// Builds the placeholder shown when an image fails to load.
  ///
  /// Receives the loader's error object. Defaults to a broken-image icon
  /// followed by [errorMessage].
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Message displayed by the default error placeholder.
  final String errorMessage;

  @override
  State<ImageViewerWidget> createState() => _ImageViewerWidgetState();
}

class _ImageViewerWidgetState extends State<ImageViewerWidget>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final List<PhotoViewScaleStateController> _scaleStateControllers;
  late int _currentIndex;
  bool _isZoomed = false;

  // Key for the Share icon button on mobile — captures its RenderBox before
  // the async gap in the consumer's share call so the iPad popover anchors
  // to the share button, not the overflow menu.
  final GlobalKey _shareButtonKey = GlobalKey();

  // Key for the overflow ⋮ button.
  final GlobalKey _overflowMenuKey = GlobalKey();

  // Horizontal inset around the gallery so swipes don't start in the Android
  // system back-gesture zone. Without this inset, on Android in portrait the
  // image fills the full screen width and the first swipe of each sequence is
  // consumed by the system as a back-gesture preview, requiring a second
  // swipe to actually flip pages. Landscape isn't affected because contained
  // images leave horizontal letterbox bands at the edges.
  static const double _kHorizontalGalleryInset = 12;

  // Pull-to-dismiss — per-pointer tracking, deduped by pointer ID.
  static const double _kDismissStartSlop = 12;
  static const double _kDismissDistanceThreshold = 0.18;
  static const double _kDismissVelocityThreshold = 900;

  final Set<int> _activePointers = <int>{};
  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};
  int? _trackedPointer;
  Offset? _dragStartPosition;
  bool _isTrackingDismissDrag = false;
  bool _isAnimatingDismiss = false;
  double _dragY = 0;
  late final AnimationController _dragAnimController;
  Animation<double>? _dragAnimation;

  bool get _canTrackDismissDrag =>
      !kIsWeb && !_isAnimatingDismiss && !_isZoomed;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _scaleStateControllers = List.generate(
      widget.items.length,
      (_) => PhotoViewScaleStateController(),
    );
    _dragAnimController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 180),
          )
          ..addListener(_onDragAnimTick)
          ..addStatusListener(_onDragAnimStatusChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _scaleStateControllers) {
      c.dispose();
    }
    _dragAnimController
      ..removeListener(_onDragAnimTick)
      ..removeStatusListener(_onDragAnimStatusChanged)
      ..dispose();
    super.dispose();
  }

  bool _stateIsZoomed(PhotoViewScaleState state) =>
      state != PhotoViewScaleState.initial &&
      state != PhotoViewScaleState.zoomedOut;

  void _onScaleStateChanged(PhotoViewScaleState state) {
    final zoomed = _stateIsZoomed(state);
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  void _onDragAnimTick() {
    final value = _dragAnimation?.value;
    if (value == null || !mounted) return;
    setState(() => _dragY = value);
  }

  void _onDragAnimStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final shouldClose = _isAnimatingDismiss;
    _isAnimatingDismiss = false;
    _dragAnimation = null;
    if (shouldClose) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (mounted && _dragY != 0) setState(() => _dragY = 0);
  }

  void _animateDragYTo(double target, {bool dismissOnComplete = false}) {
    if ((_dragY - target).abs() < 0.5) {
      if (dismissOnComplete) {
        if (mounted) Navigator.of(context).maybePop();
      } else if (_dragY != target && mounted) {
        setState(() => _dragY = target);
      }
      return;
    }
    _dragAnimController.stop();
    _dragAnimController.duration = dismissOnComplete
        ? const Duration(milliseconds: 140)
        : const Duration(milliseconds: 180);
    _isAnimatingDismiss = dismissOnComplete;
    _dragAnimation = Tween<double>(begin: _dragY, end: target).animate(
      CurvedAnimation(
        parent: _dragAnimController,
        curve: dismissOnComplete ? Curves.easeOutCubic : Curves.easeOutQuart,
      ),
    );
    _dragAnimController.forward(from: 0);
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _velocityTrackers[event.pointer] = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);

    if (!_canTrackDismissDrag || event.kind == PointerDeviceKind.mouse) {
      return;
    }

    if (_activePointers.length > 1) {
      _cancelDismissDrag(animateBack: _dragY > 0);
      return;
    }

    _trackedPointer = event.pointer;
    _dragStartPosition = event.position;
    _isTrackingDismissDrag = false;
    if (_dragAnimController.isAnimating) {
      _dragAnimController.stop();
      _dragAnimation = null;
      _isAnimatingDismiss = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _velocityTrackers[event.pointer]?.addPosition(
      event.timeStamp,
      event.position,
    );

    if (!_canTrackDismissDrag ||
        _trackedPointer != event.pointer ||
        _dragStartPosition == null ||
        _activePointers.length != 1) {
      return;
    }

    final delta = event.position - _dragStartPosition!;
    if (!_isTrackingDismissDrag) {
      if (delta.dy <= _kDismissStartSlop || delta.dy.abs() <= delta.dx.abs()) {
        return;
      }
      _isTrackingDismissDrag = true;
    }

    final nextDragY = math.max(0.0, delta.dy);
    if (nextDragY == _dragY) return;
    setState(() => _dragY = nextDragY);
  }

  void _onPointerUp(PointerUpEvent event) {
    _velocityTrackers[event.pointer]?.addPosition(
      event.timeStamp,
      event.position,
    );
    _finishPointerTracking(event.pointer);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _finishPointerTracking(event.pointer, canceled: true);
  }

  void _finishPointerTracking(int pointer, {bool canceled = false}) {
    final tracker = _velocityTrackers.remove(pointer);
    _activePointers.remove(pointer);

    if (_trackedPointer != pointer) return;

    final shouldSettle = _isTrackingDismissDrag && !canceled;
    final velocityY = tracker?.getVelocity().pixelsPerSecond.dy ?? 0;
    _trackedPointer = null;
    _dragStartPosition = null;
    _isTrackingDismissDrag = false;

    if (shouldSettle) {
      _settleDismissDrag(velocityY);
    } else if (canceled && _dragY > 0) {
      _animateDragYTo(0);
    }
  }

  void _cancelDismissDrag({required bool animateBack}) {
    _trackedPointer = null;
    _dragStartPosition = null;
    _isTrackingDismissDrag = false;
    if (animateBack && _dragY > 0) _animateDragYTo(0);
  }

  void _settleDismissDrag(double velocityY) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final shouldDismiss =
        _dragY > screenHeight * _kDismissDistanceThreshold ||
        velocityY > _kDismissVelocityThreshold;
    _animateDragYTo(
      shouldDismiss ? screenHeight : 0,
      dismissOnComplete: shouldDismiss,
    );
  }

  void _handlePageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isZoomed = _stateIsZoomed(_scaleStateControllers[index].scaleState);
    });
    widget.onPageChanged?.call(index);
  }

  void _handleClose() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _handleMenuSelected(_ImageViewerMenuAction action) {
    final item = widget.items[_currentIndex];
    switch (action) {
      case _ImageViewerMenuAction.share:
        // Capture the share button's RenderBox synchronously — before any
        // async gap in the consumer's share call — so the iPad popover anchor
        // rect is valid even after an await.
        final renderBox =
            _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
        final rect = renderBox == null
            ? null
            : renderBox.localToGlobal(Offset.zero) & renderBox.size;
        widget.onShare?.call(item, _currentIndex, rect);
      case _ImageViewerMenuAction.download:
        widget.onDownload?.call(item, _currentIndex);
      case _ImageViewerMenuAction.delete:
        widget.onDelete?.call(item, _currentIndex);
    }
  }

  String _defaultPageIndicator(int current, int total) =>
      '${current + 1} / $total';

  Widget _defaultLoading(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: widget.foregroundColor),
    );
  }

  Widget _defaultError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: widget.foregroundColor,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(
              widget.errorMessage,
              style: TextStyle(color: widget.foregroundColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final total = widget.items.length;
    final indicator = (widget.pageIndicatorBuilder ?? _defaultPageIndicator)
        .call(_currentIndex, total);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final dismissProgress = (_dragY / screenHeight).clamp(0.0, 1.0);
    final bgAlpha = 1.0 - dismissProgress * 0.7;

    final gallery = ScrollConfiguration(
      behavior: const _ViewerScrollBehavior(),
      child: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: BoxDecoration(color: widget.backgroundColor),
        pageController: _pageController,
        onPageChanged: _handlePageChanged,
        // Gallery-level callback lets photo_view manage its own scroll lock
        // (disabling page swiping while an image is zoomed in).
        scaleStateChangedCallback: _onScaleStateChanged,
        itemCount: total,
        loadingBuilder: (context, event) =>
            widget.loadingBuilder?.call(context) ?? _defaultLoading(context),
        builder: (context, index) {
          final item = widget.items[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: item.provider,
            scaleStateController: _scaleStateControllers[index],
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * widget.minScale,
            maxScale: PhotoViewComputedScale.contained * widget.maxScale,
            // Only activate the Hero on the currently-visible page.
            // Adjacent pages preloaded by PageView must NOT carry a Hero widget,
            // otherwise multiple competing Heroes with different tags exist in
            // the tree simultaneously, causing the wrong tag to match on pop.
            heroAttributes: item.heroTag != null && index == _currentIndex
                ? PhotoViewHeroAttributes(tag: item.heroTag!)
                : null,
            filterQuality: FilterQuality.high,
            // Claim the entire page area so drags starting in transparent
            // regions (around a contained image) are captured and count
            // toward the page-flip gesture on both web and mobile.
            gestureDetectorBehavior: HitTestBehavior.opaque,
            errorBuilder: (context, error, stackTrace) =>
                widget.errorBuilder?.call(context, error) ??
                _defaultError(context),
          );
        },
      ),
    );

    // The Listener wraps only the gallery. Arrow buttons are Stack siblings so
    // their taps never enter the PhotoViewGallery gesture chain.
    final listenedGallery = Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: isWeb ? null : _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: gallery,
    );

    // Stack is always used so the featured badge and web arrows can be
    // layered above the gallery without nesting inside the Listener.
    final body = Stack(
      fit: StackFit.expand,
      children: [
        if (!isWeb)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kHorizontalGalleryInset,
            ),
            child: listenedGallery,
          )
        else
          listenedGallery,
        // Web: arrow buttons overlaid outside the Listener so photo_view
        // gesture recognizers can't absorb the taps.
        if (isWeb && total > 1) ...[
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrowButton(
                  icon: Icons.chevron_left,
                  foregroundColor: widget.foregroundColor,
                  onTap: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
          if (_currentIndex < total - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavArrowButton(
                  icon: Icons.chevron_right,
                  foregroundColor: widget.foregroundColor,
                  onTap: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
            ),
        ],
      ],
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            _currentIndex < total - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            _currentIndex > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: IgnorePointer(
        ignoring: _isAnimatingDismiss,
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Scaffold(
            backgroundColor: widget.backgroundColor.withValues(alpha: bgAlpha),
            extendBodyBehindAppBar: true,
            appBar: _ImageViewerAppBar(
              title: indicator,
              foregroundColor: widget.foregroundColor,
              isWeb: isWeb,
              shareButtonKey: _shareButtonKey,
              overflowMenuKey: _overflowMenuKey,
              onClose: _handleClose,
              onShare: widget.onShare == null
                  ? null
                  : () => _handleMenuSelected(_ImageViewerMenuAction.share),
              onDownload: widget.onDownload == null
                  ? null
                  : () => _handleMenuSelected(_ImageViewerMenuAction.download),
              onDelete: widget.onDelete == null
                  ? null
                  : () => _handleMenuSelected(_ImageViewerMenuAction.delete),
            ),
            body: body,
          ),
        ),
      ),
    );
  }
}

/// Identifies an item in the viewer's overflow menu.
enum _ImageViewerMenuAction { share, download, delete }

/// Transparent app bar with a close button, page indicator, and action buttons.
///
/// On web: Download is a direct icon button; Share and Delete are in the overflow menu.
/// On mobile: Share is a direct icon button; Download and Delete are in the overflow menu.
class _ImageViewerAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ImageViewerAppBar({
    required this.title,
    required this.foregroundColor,
    required this.isWeb,
    this.shareButtonKey,
    this.overflowMenuKey,
    this.onClose,
    this.onShare,
    this.onDownload,
    this.onDelete,
  });

  final String title;
  final Color foregroundColor;
  final bool isWeb;

  /// Key attached to the mobile Share [IconButton] so the parent state can
  /// read its [RenderBox] for the iPad share-sheet anchor rect.
  final GlobalKey? shareButtonKey;

  /// Key attached to the overflow [PopupMenuButton].
  final GlobalKey? overflowMenuKey;

  /// Called when the user taps the close button. When provided, the caller
  /// can intercept the pop to restore Hero state before dismissing.
  final VoidCallback? onClose;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  // Overflow menu is shown when there are items to put in it.
  // Web: Share + Delete. Mobile: Download + Delete.
  bool get _hasOverflow => isWeb
      ? (onShare != null || onDelete != null)
      : (onDownload != null || onDelete != null);

  void _handleSelected(_ImageViewerMenuAction action) {
    switch (action) {
      case _ImageViewerMenuAction.share:
        onShare?.call();
      case _ImageViewerMenuAction.download:
        onDownload?.call();
      case _ImageViewerMenuAction.delete:
        onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: foregroundColor,
      iconTheme: IconThemeData(color: foregroundColor),
      centerTitle: true,
      title: Text(
        title,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: onClose ?? () => Navigator.of(context).maybePop(),
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
        if (_hasOverflow)
          PopupMenuButton<_ImageViewerMenuAction>(
            key: overflowMenuKey,
            icon: Icon(Icons.more_vert, color: foregroundColor),
            tooltip: 'More actions',
            onSelected: _handleSelected,
            itemBuilder: (context) => [
              // Web: Share in overflow.
              if (isWeb && onShare != null)
                const PopupMenuItem(
                  value: _ImageViewerMenuAction.share,
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // Mobile: Download in overflow.
              if (!isWeb && onDownload != null)
                const PopupMenuItem(
                  value: _ImageViewerMenuAction.download,
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Download'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              // Both platforms: Delete.
              if (onDelete != null)
                const PopupMenuItem(
                  value: _ImageViewerMenuAction.delete,
                  child: ListTile(
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

/// Allows all pointer device kinds (touch, mouse, stylus) to drag-scroll the
/// gallery's [PageView]. The Flutter default restricts drag to touch/stylus
/// only, which prevents single-swipe page turns on web with a mouse.
class _ViewerScrollBehavior extends MaterialScrollBehavior {
  const _ViewerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Circular arrow button for click-based navigation on web.
class _NavArrowButton extends StatelessWidget {
  const _NavArrowButton({
    required this.icon,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: foregroundColor, size: 28),
        ),
      ),
    );
  }
}
