import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/photo_view.dart';

import '_image_viewer_file_io.dart'
    if (dart.library.html) '_image_viewer_file_web.dart'
    as file_loader;
import 'image_viewer_app_bar.dart';
import 'nav_arrow_button.dart';
import 'page_dots.dart';
import 'placeholder_image.dart';
import 'viewer_scrim.dart';

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
  /// [id] identifies the image in the consumer's own model.
  /// [filename] is a suggested file name for share/download flows.
  /// [title] is a short name shown in the viewer's header.
  /// [caption] is longer descriptive text shown in the viewer's footer.
  /// [heroTag] enables a [Hero] transition into the viewer from a matching
  /// thumbnail.
  /// [placeholder] is a low-resolution image shown until [provider] loads.
  const ImageViewerItem({
    required this.provider,
    this.id,
    this.filename,
    this.title,
    this.caption,
    this.heroTag,
    this.placeholder,
  });

  /// Loads an image from the app's asset bundle.
  factory ImageViewerItem.asset(
    String name, {
    String? package,
    String? id,
    String? filename,
    String? title,
    String? caption,
    Object? heroTag,
    ImageProvider? placeholder,
  }) => ImageViewerItem(
    provider: AssetImage(name, package: package),
    id: id,
    filename: filename,
    title: title,
    caption: caption,
    heroTag: heroTag,
    placeholder: placeholder,
  );

  /// Loads an image from a network URL.
  factory ImageViewerItem.network(
    String url, {
    Map<String, String>? headers,
    String? id,
    String? filename,
    String? title,
    String? caption,
    Object? heroTag,
    ImageProvider? placeholder,
  }) => ImageViewerItem(
    provider: NetworkImage(url, headers: headers),
    id: id,
    filename: filename,
    title: title,
    caption: caption,
    heroTag: heroTag,
    placeholder: placeholder,
  );

  /// Loads an image from a file on the local device.
  ///
  /// Not supported on Flutter web — calling this on a web target throws
  /// [UnsupportedError] when the image is loaded. Use [ImageViewerItem.network]
  /// or [ImageViewerItem.asset] on web instead.
  factory ImageViewerItem.file(
    String path, {
    String? id,
    String? filename,
    String? title,
    String? caption,
    Object? heroTag,
    ImageProvider? placeholder,
  }) => ImageViewerItem(
    provider: file_loader.fileImageProvider(path),
    id: id,
    filename: filename,
    title: title,
    caption: caption,
    heroTag: heroTag,
    placeholder: placeholder,
  );

  /// The underlying [ImageProvider] used to load this image.
  final ImageProvider provider;

  /// Optional identifier for the image in the consumer's own model.
  ///
  /// Forwarded to action callbacks so consumers can act on the right record
  /// without mapping the index back to their data. When the viewer's `items`
  /// change while it is open, ids are also how it recognises the image the
  /// user was looking at and stays on it.
  final String? id;

  /// Optional file name (e.g. `kitchen.jpg`) for the image.
  ///
  /// Forwarded to action callbacks so share/download flows can name the file.
  final String? filename;

  /// Optional human-readable title for the image.
  ///
  /// Shown in the viewer's header above the page indicator, in place of
  /// [filename]. Also forwarded to action callbacks so consumers can label
  /// share/download flows without looking the title up again.
  final String? title;

  /// Optional caption describing the image, shown in the viewer's footer.
  final String? caption;

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

  /// Optional low-resolution image, such as the thumbnail the viewer was
  /// opened from, shown in place of the loading indicator until [provider]
  /// has loaded.
  ///
  /// Pass the same [ImageProvider] the thumbnail used: it is then already in
  /// memory, so the page shows it at once and a [Hero] from the thumbnail
  /// lands on it. It is drawn fitted like the full image, so give it the same
  /// aspect ratio. A placeholder that fails to load is ignored.
  final ImageProvider? placeholder;
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

/// A consumer-defined action, shown in the viewer's overflow menu or as a
/// button in its header.
///
/// Use this for actions beyond the built-in Share / Download / Delete, such
/// as "Set as featured". Pass a list to [ImageViewerWidget.actions].
class ImageViewerAction {
  /// Creates an [ImageViewerAction].
  ///
  /// [label] is the menu item text (or the button's tooltip), [icon] its
  /// icon, and [onSelected] is called with the visible image when the action
  /// is chosen.
  const ImageViewerAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.showInAppBar = false,
    this.isVisible,
  });

  /// Text shown for the menu item.
  final String label;

  /// Icon shown before [label].
  final IconData icon;

  /// Called with the visible item and its index when the action is chosen.
  final ImageViewerActionCallback onSelected;

  /// Whether the action is a button in the header rather than an entry in
  /// the overflow menu. Defaults to `false`.
  final bool showInAppBar;

  /// Decides, for the visible image, whether the action is offered — for
  /// example, hiding "Set as featured" on the image that already is. When
  /// `null`, the action is offered for every image.
  final bool Function(ImageViewerItem item, int index)? isVisible;
}

/// Builds the header title for the visible image.
///
/// [item] is the visible image, [index] its zero-based position and [total]
/// the number of images.
typedef ImageViewerTitleBuilder =
    Widget Function(
      BuildContext context,
      ImageViewerItem item,
      int index,
      int total,
    );

/// Builds the footer for the visible image, or returns `null` for none.
///
/// [item] is the visible image, [index] its zero-based position and [total]
/// the number of images.
typedef ImageViewerFooterBuilder =
    Widget? Function(
      BuildContext context,
      ImageViewerItem item,
      int index,
      int total,
    );

/// How the viewer's header and footer sit relative to the image.
enum ImageViewerControlsLayout {
  /// The image fills the screen and the header and footer float over it on a
  /// dark gradient. Tapping the image hides or shows them, unless
  /// [ImageViewerWidget.controlsHideOnTap] is `false`. The usual layout for
  /// phones.
  overlay,

  /// The header and footer sit above and below the image, which fits in the
  /// space between them, so they never cover it. The usual layout for
  /// tablets and desktop.
  inset,
}

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
/// * **Escape** — closes the viewer.
///
/// ## Layout
///
/// Follows the Material 3 breakpoints. In windows narrower than 600dp or
/// shorter than 480dp (phones, upright or on their side), the image fills the screen and the header and footer float over
/// it on a dark gradient; tapping the image hides or shows them. In wider
/// windows (tablets, desktop and most browser windows), the header and
/// footer sit above and below the image, which fits between them with a
/// 24dp margin so they never cover it. Choose a layout yourself with
/// [controlsLayout], and set the space around the image with
/// [contentPadding].
///
/// ## Header and footer
///
/// The header shows the image's [ImageViewerItem.title] (or its
/// [ImageViewerItem.filename]) above the page indicator; replace it with
/// [titleBuilder]. The footer shows the image's [ImageViewerItem.caption] and,
/// for up to 20 images, a row of page dots; replace it with [footerBuilder].
///
/// ## Actions
///
/// Provide [onShare], [onDownload], and/or [onDelete] to enable the
/// corresponding menu items. Menu items with `null` callbacks are hidden.
/// Add your own actions with [actions], as overflow menu entries or, with
/// [ImageViewerAction.showInAppBar], header buttons. The overflow menu itself
/// is hidden when it would be empty.
///
/// ## Changing items while open
///
/// [items] may grow or shrink while the viewer is open — for example after a
/// delete. The viewer stays on the image the user was viewing when it is
/// still present (matched by [ImageViewerItem.id], or by image source when no
/// id is set); otherwise it shows the image now at the same position, or the
/// last image if that position no longer exists. Zoom returns to
/// fit-to-screen whenever images are removed, reordered or inserted ahead of
/// others.
///
/// Give every item an [ImageViewerItem.id] if the list can change. Without
/// ids, an item built from a provider that has no value equality (a custom
/// [ImageProvider], or a [MemoryImage] over freshly decoded bytes) looks like
/// a different image on every rebuild.
///
/// [items] must never be empty: close the viewer instead of rebuilding it
/// with an empty list when the last image is removed.
///
/// ## Foundation
///
/// Loading and error placeholders are customisable via [loadingBuilder] and
/// [errorBuilder], and the page indicator text via [pageIndicatorBuilder].
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => ImageViewerWidget(
///       items: [
///         ImageViewerItem.network('https://example.com/a.jpg'),
///         ImageViewerItem.network('https://example.com/b.jpg'),
///       ],
///       onShare: (item, index, sharePositionOrigin) => share(item),
///     ),
///   ),
/// );
/// ```
class ImageViewerWidget extends StatefulWidget {
  /// Creates an [ImageViewerWidget].
  ///
  /// [items] is the non-empty list of images to display. It may change
  /// while the viewer is open, but must never become empty.
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
    this.actions = const [],
    this.onPageChanged,
    this.pageIndicatorBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.errorMessage = 'Unable to load image',
    this.controlsLayout,
    this.contentPadding,
    this.controlsHideOnTap = true,
    this.titleBuilder,
    this.footerBuilder,
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

  /// Additional actions. Header buttons ([ImageViewerAction.showInAppBar])
  /// follow Share or Download; menu entries are shown in order above Delete.
  final List<ImageViewerAction> actions;

  /// Called whenever the visible page changes, with the new zero-based index.
  final ValueChanged<int>? onPageChanged;

  /// Builds the page indicator text shown in the header.
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

  /// How the header and footer sit relative to the image.
  ///
  /// When `null` (the default), windows narrower than 600dp or shorter than
  /// 480dp use [ImageViewerControlsLayout.overlay] and others
  /// [ImageViewerControlsLayout.inset], following the Material 3 breakpoints.
  final ImageViewerControlsLayout? controlsLayout;

  /// Space around the image, inside the area it is shown in. Swipes and
  /// pull-to-dismiss work from it as well as from the image.
  ///
  /// When `null`, an [ImageViewerControlsLayout.inset] layout uses the 24dp
  /// Material 3 margin on every side. An
  /// [ImageViewerControlsLayout.overlay] layout lets the image fill the
  /// screen, apart from 12dp at the sides on mobile, which keeps page swipes
  /// clear of Android's back gesture.
  final EdgeInsetsGeometry? contentPadding;

  /// Whether tapping the image hides or shows the header and footer in an
  /// [ImageViewerControlsLayout.overlay] layout. Defaults to `true`.
  final bool controlsHideOnTap;

  /// Builds the header title for the visible image.
  ///
  /// Defaults to the image's [ImageViewerItem.title], or its
  /// [ImageViewerItem.filename], above the page indicator, or the page
  /// indicator alone when the image has neither.
  final ImageViewerTitleBuilder? titleBuilder;

  /// Builds the footer for the visible image; return `null` for none.
  ///
  /// Defaults to the image's [ImageViewerItem.caption] and, for 2 to 20
  /// images, a row of page dots. There is no footer when the image has no
  /// caption and there is a single image.
  final ImageViewerFooterBuilder? footerBuilder;

  @override
  State<ImageViewerWidget> createState() => _ImageViewerWidgetState();
}

class _ImageViewerWidgetState extends State<ImageViewerWidget>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late List<PhotoViewScaleStateController> _scaleStateControllers;
  late int _currentIndex;
  bool _isZoomed = false;

  // Whether the header and footer are showing, in the overlay layout.
  bool _controlsVisible = true;

  // The viewer's own copy of `widget.items`. Comparing against a copy is what
  // lets it notice a consumer changing its list in place, where the old and
  // new widgets share one (already changed) list.
  late List<ImageViewerItem> _items;

  // Bumped to rebuild the gallery from scratch when images change page.
  int _galleryEpoch = 0;

  // Key for the Share icon button on mobile — captures its RenderBox before
  // the async gap in the consumer's share call so the iPad popover anchors
  // to the share button, not the overflow menu.
  final GlobalKey _shareButtonKey = GlobalKey();

  // Key for the overflow ⋮ button.
  final GlobalKey _overflowMenuKey = GlobalKey();

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
    _items = List.of(widget.items);
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _scaleStateControllers = List.generate(
      _items.length,
      (_) => PhotoViewScaleStateController(),
      growable: true,
    );
    _dragAnimController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 180),
          )
          ..addListener(_onDragAnimTick)
          ..addStatusListener(_onDragAnimStatusChanged);
  }

  // Two items show the same image when they are the same instance, share an
  // id, or (with no ids to go on) load from an equal source.
  static bool _isSameImage(ImageViewerItem a, ImageViewerItem b) {
    if (identical(a, b)) return true;
    if (a.id != null || b.id != null) return a.id == b.id;
    return a.provider == b.provider;
  }

  @override
  void didUpdateWidget(covariant ImageViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.items;
    // Nothing to show: keep the last images until the consumer closes us.
    if (next.isEmpty) return;

    // Every image is still on its page (new ones may follow): keep the
    // gallery, and with it the user's position and zoom.
    var pagesKept = next.length >= _items.length;
    for (var i = 0; pagesKept && i < _items.length; i++) {
      pagesKept = _isSameImage(_items[i], next[i]);
    }
    if (pagesKept) {
      while (_scaleStateControllers.length < next.length) {
        _scaleStateControllers.add(PhotoViewScaleStateController());
      }
      _items = List.of(next);
      return;
    }

    // Images moved between pages. Stay on the image the user was viewing if
    // it survived the change; otherwise keep the position, clamped into the
    // new range.
    final viewed = _items[_currentIndex];
    final found = next.indexWhere((item) => _isSameImage(item, viewed));
    final index = found != -1
        ? found
        : math.min(_currentIndex, next.length - 1);
    final indexChanged = index != _currentIndex;

    // The gallery keeps zoom and pan per page, not per image, so rebuild it
    // already positioned on the right page rather than let images inherit
    // each other's state or flash past on the way to a jump.
    final oldPageController = _pageController;
    final oldScaleStateControllers = _scaleStateControllers;
    _items = List.of(next);
    _currentIndex = index;
    _isZoomed = false;
    _galleryEpoch++;
    _pageController = PageController(initialPage: index);
    _scaleStateControllers = List.generate(
      next.length,
      (_) => PhotoViewScaleStateController(),
      growable: true,
    );
    // The old gallery holds its controllers until this frame has built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldPageController.dispose();
      for (final c in oldScaleStateControllers) {
        c.dispose();
      }
      if (mounted && indexChanged) widget.onPageChanged?.call(index);
    });
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

  void _invoke(ImageViewerActionCallback callback) =>
      callback(_items[_currentIndex], _currentIndex);

  void _handleShare() {
    // Capture the share button's RenderBox synchronously — before any
    // async gap in the consumer's share call — so the iPad popover anchor
    // rect is valid even after an await.
    final renderBox =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final rect = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    widget.onShare?.call(_items[_currentIndex], _currentIndex, rect);
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

  // Material 3's compact breakpoints: a window narrower than 600dp, or
  // shorter than 480dp (a phone in landscape), is a phone's.
  static const double _kCompactWidth = 600;
  static const double _kCompactHeight = 480;

  // Keeps the gallery, with its page and zoom, when a resize or rotation
  // moves it between the overlay and inset layouts.
  final GlobalKey _galleryKey = GlobalKey();

  bool _actionIsVisible(ImageViewerAction action) =>
      action.isVisible?.call(_items[_currentIndex], _currentIndex) ?? true;

  void _toggleControls() =>
      setState(() => _controlsVisible = !_controlsVisible);

  Widget _defaultTitle(ImageViewerItem item, String indicator) {
    final color = widget.foregroundColor;
    final indicatorText = Text(
      indicator,
      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500),
    );
    final name = item.title ?? item.filename;
    if (name == null) return indicatorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          indicator,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget? _defaultFooter(ImageViewerItem item, int index, int total) {
    final caption = item.caption;
    // Past 20 images the dots get too small to tell apart; the header
    // already shows the position.
    final showDots = total > 1 && total <= 20;
    if (caption == null && !showDots) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption != null)
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: widget.foregroundColor, fontSize: 13),
          ),
        if (caption != null && showDots) const SizedBox(height: 8),
        if (showDots)
          PageDots(
            count: total,
            currentIndex: index,
            color: widget.foregroundColor,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final total = _items.length;
    final item = _items[_currentIndex];
    final indicator = (widget.pageIndicatorBuilder ?? _defaultPageIndicator)
        .call(_currentIndex, total);

    final screenSize = MediaQuery.sizeOf(context);
    final layout =
        widget.controlsLayout ??
        (screenSize.width < _kCompactWidth ||
                screenSize.height < _kCompactHeight
            ? ImageViewerControlsLayout.overlay
            : ImageViewerControlsLayout.inset);
    final isOverlay = layout == ImageViewerControlsLayout.overlay;
    final contentPadding =
        (widget.contentPadding ??
                (isOverlay
                    // Keeps swipes clear of Android's back gesture: without it, the
                    // first swipe of each sequence previews going back instead of
                    // turning the page.
                    ? EdgeInsets.symmetric(horizontal: isWeb ? 0 : 12)
                    : const EdgeInsets.all(24)))
            .resolve(Directionality.of(context));
    // Even padding can be left to photo_view, which then fits the image
    // inside it while the gallery, and its gestures, cover the margin too.
    final isEvenPadding =
        contentPadding.left == contentPadding.right &&
        contentPadding.top == contentPadding.bottom;
    final canToggleControls = isOverlay && widget.controlsHideOnTap;
    // Taps on a page that is loading or failed don't reach photo_view.
    Widget tapToToggle(Widget child) => canToggleControls
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: child,
          )
        : child;
    // Hidden controls only exist in the overlay layout.
    final controlsVisible = !isOverlay || _controlsVisible;

    final onDownload = widget.onDownload;
    final onDelete = widget.onDelete;
    final dismissProgress = (_dragY / screenSize.height).clamp(0.0, 1.0);
    final bgAlpha = 1.0 - dismissProgress * 0.7;

    Widget buildGallery(Size? customSize) => ScrollConfiguration(
      behavior: const _ViewerScrollBehavior(),
      child: PhotoViewGallery.builder(
        key: ValueKey(_galleryEpoch),
        customSize: customSize,
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        pageController: _pageController,
        onPageChanged: _handlePageChanged,
        // Gallery-level callback lets photo_view manage its own scroll lock
        // (disabling page swiping while an image is zoomed in).
        scaleStateChangedCallback: _onScaleStateChanged,
        itemCount: total,
        loadingBuilder: (context, event) => tapToToggle(
          widget.loadingBuilder?.call(context) ?? _defaultLoading(context),
        ),
        builder: (context, index) {
          final item = _items[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: switch (item.placeholder) {
              final placeholder? => PlaceholderImage(
                item.provider,
                placeholder,
              ),
              null => item.provider,
            },
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
            onTapUp: canToggleControls ? (_, _, _) => _toggleControls() : null,
            errorBuilder: (context, error, stackTrace) => tapToToggle(
              widget.errorBuilder?.call(context, error) ??
                  _defaultError(context),
            ),
          );
        },
      ),
    );

    // The Listener wraps only the gallery. Arrow buttons are Stack siblings so
    // their taps never enter the PhotoViewGallery gesture chain.
    final listenedGallery = Listener(
      key: _galleryKey,
      // Pull-to-dismiss also starts in the margin around the image.
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: isWeb ? null : _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: isEvenPadding
          ? LayoutBuilder(
              builder: (context, constraints) =>
                  buildGallery(contentPadding.deflateSize(constraints.biggest)),
            )
          : Padding(padding: contentPadding, child: buildGallery(null)),
    );

    // Web: arrow buttons overlaid outside the Listener so photo_view gesture
    // recognizers can't absorb the taps. [wrap] lets the overlay fade them.
    List<Widget> buildArrows(Widget Function(Widget) wrap) => [
      if (isWeb && _currentIndex > 0)
        Positioned(
          left: 16,
          top: 0,
          bottom: 0,
          child: wrap(
            Center(
              child: NavArrowButton(
                icon: Icons.chevron_left,
                foregroundColor: widget.foregroundColor,
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ),
        ),
      if (isWeb && _currentIndex < total - 1)
        Positioned(
          right: 16,
          top: 0,
          bottom: 0,
          child: wrap(
            Center(
              child: NavArrowButton(
                icon: Icons.chevron_right,
                foregroundColor: widget.foregroundColor,
                onTap: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ),
        ),
    ];

    final appBarActions = <ImageViewerAppBarAction>[];
    final menuActions = <ImageViewerAppBarAction>[];
    for (final action in widget.actions) {
      if (!_actionIsVisible(action)) continue;
      (action.showInAppBar ? appBarActions : menuActions).add((
        label: action.label,
        icon: action.icon,
        onPressed: () => _invoke(action.onSelected),
      ));
    }
    final header = ImageViewerAppBar(
      title:
          widget.titleBuilder?.call(context, item, _currentIndex, total) ??
          _defaultTitle(item, indicator),
      foregroundColor: widget.foregroundColor,
      isWeb: isWeb,
      shareButtonKey: _shareButtonKey,
      overflowMenuKey: _overflowMenuKey,
      // Like AppBar's own back button, left out when it would do nothing.
      onClose: (ModalRoute.of(context)?.canPop ?? false) ? _handleClose : null,
      onShare: widget.onShare == null ? null : _handleShare,
      onDownload: onDownload == null ? null : () => _invoke(onDownload),
      onDelete: onDelete == null ? null : () => _invoke(onDelete),
      appBarActions: appBarActions,
      menuActions: menuActions,
    );

    final footerContent = widget.footerBuilder != null
        ? widget.footerBuilder!(context, item, _currentIndex, total)
        : _defaultFooter(item, _currentIndex, total);
    final footer = footerContent == null
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, isOverlay ? 24 : 8, 16, 12),
              child: footerContent,
            ),
          );

    final Widget body;
    if (isOverlay) {
      // Over the image the controls need a scrim to stay legible, and fade
      // out together when the image is tapped.
      Widget fade(Widget child) => IgnorePointer(
        ignoring: !controlsVisible,
        child: AnimatedOpacity(
          opacity: controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      );
      body = Stack(
        fit: StackFit.expand,
        children: [
          listenedGallery,
          ...buildArrows(fade),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: fade(ViewerScrim(fromTop: true, child: header)),
          ),
          if (footer != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: fade(ViewerScrim(fromTop: false, child: footer)),
            ),
        ],
      );
    } else {
      body = Column(
        children: [
          header,
          Expanded(
            child: SafeArea(
              top: false,
              bottom: footer == null,
              child: Stack(
                fit: StackFit.expand,
                children: [listenedGallery, ...buildArrows((child) => child)],
              ),
            ),
          ),
          ?footer,
        ],
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _handleClose();
          return KeyEventResult.handled;
        }
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
            body: body,
          ),
        ),
      ),
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
