import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_source.dart';

/// A reusable PDF viewer with optional zoom controls, page indicator, and
/// in-document text search.
///
/// Backed by the `pdfrx` rendering engine. Renders a PDF from any
/// [PdfSource] — a network [Uri], local file path, or in-memory bytes.
///
/// ## Interactions
///
/// - **Mobile**: pinch-to-zoom and pan are enabled by default.
/// - **Web**: Ctrl/Cmd + scroll-wheel zooms in and out; on-screen +/− buttons
///   are also shown when [showZoomControlsOnWeb] is true.
/// - **All platforms**: keyboard navigation (arrow keys, Page Up/Down) is
///   enabled by default.
///
/// ## Search
///
/// When [enableSearch] is `true`, a search bar appears above the viewer.
/// Typed queries are debounced by [searchDebounce] before being submitted to
/// the underlying [PdfTextSearcher]. Matches are highlighted in-document via
/// `pagePaintCallbacks` and the user can step between them with the next/
/// previous controls. A status label indicates the current match position or
/// "No matches" when the query has no hits.
///
/// ## Error handling
///
/// If [errorBuilder] is provided it replaces the default in-viewer error
/// banner shown when the document fails to load (bad URL, malformed bytes,
/// missing file, etc.).
class PdfViewerWidget extends StatefulWidget {
  /// Creates a [PdfViewerWidget].
  const PdfViewerWidget({
    super.key,
    required this.source,
    this.enableSearch = false,
    this.showZoomControlsOnWeb = true,
    this.showPageIndicator = true,
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.errorBuilder,
    this.searchDebounce = const Duration(milliseconds: 300),
  }) : assert(minScale > 0 && minScale <= maxScale);

  /// The PDF document to render.
  final PdfSource source;

  /// Whether the in-document search bar is shown.
  final bool enableSearch;

  /// Whether +/− zoom buttons are shown on web. Has no effect on other
  /// platforms, where pinch-to-zoom is the primary zoom interaction.
  final bool showZoomControlsOnWeb;

  /// Whether the "Page X / Y" overlay is shown in the bottom-right corner.
  final bool showPageIndicator;

  /// Lower bound for the zoom level passed to `pdfrx`.
  final double minScale;

  /// Upper bound for the zoom level passed to `pdfrx`.
  final double maxScale;

  /// Called whenever the visible page changes. Receives the 1-based page
  /// number.
  final ValueChanged<int>? onPageChanged;

  /// Called once the document has loaded successfully. Receives the total
  /// page count.
  final void Function(int pageCount)? onDocumentLoaded;

  /// Optional builder for an error UI shown in place of the document when
  /// loading fails.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Idle time before a typed search query is submitted to the searcher.
  final Duration searchDebounce;

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  late final PdfViewerController _controller;
  // Lazily created inside onViewerReady: pdfrx's PdfTextSearcher constructor
  // immediately dereferences controller.document, which only exists after the
  // viewer attaches and the document has loaded.
  PdfTextSearcher? _searcher;
  final TextEditingController _searchInput = TextEditingController();
  Timer? _debounce;

  bool _viewerReady = false;
  int? _currentPage;
  int _pageCount = 0;
  bool _querySubmitted = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void didUpdateWidget(covariant PdfViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sourceChanged = oldWidget.source != widget.source;
    final searchDisabled = oldWidget.enableSearch && !widget.enableSearch;
    if (!sourceChanged && !searchDisabled) {
      return;
    }
    setState(() {
      if (sourceChanged) {
        _resetStateForNewSource();
      } else if (searchDisabled) {
        _clearSearchState(disposeSearcher: false);
      }
    });
  }

  void _clearSearchState({required bool disposeSearcher}) {
    _debounce?.cancel();
    _searchInput.clear();
    _searcher?.resetTextSearch();
    _querySubmitted = false;
    if (disposeSearcher) {
      _searcher
        ?..removeListener(_onSearchUpdate)
        ..dispose();
      _searcher = null;
    }
  }

  // Drops the searcher so onViewerReady recreates it bound to the freshly
  // loaded document, and rolls viewer state back to "not ready yet" until the
  // new document signals ready.
  void _resetStateForNewSource() {
    _clearSearchState(disposeSearcher: true);
    _viewerReady = false;
    _currentPage = null;
    _pageCount = 0;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchInput.dispose();
    _searcher
      ?..removeListener(_onSearchUpdate)
      ..dispose();
    super.dispose();
  }

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(widget.searchDebounce, () {
      if (!mounted) return;
      final searcher = _searcher;
      if (searcher == null) return;
      if (query.isEmpty) {
        searcher.resetTextSearch();
        setState(() => _querySubmitted = false);
      } else {
        searcher.startTextSearch(query);
        setState(() => _querySubmitted = true);
      }
    });
  }

  void _paintMatches(Canvas canvas, Rect pageRect, PdfPage page) {
    _searcher?.pageTextMatchPaintCallback(canvas, pageRect, page);
  }

  // pdfrx's PdfTextSearcher updates currentIndex in goToNext/PrevMatch but
  // does not notify listeners, so the "X of Y" label only refreshes when
  // navigation crosses a page boundary (which incidentally triggers a
  // rebuild via onPageChanged). setState here keeps the label in sync for
  // same-page navigation too. pdfrx also stops at the ends instead of
  // wrapping, so detect the boundary and jump to the opposite end.
  Future<void> _stepMatch({required bool forward}) async {
    final searcher = _searcher;
    if (searcher == null) return;
    final total = searcher.matches.length;
    if (total == 0) return;
    final current = searcher.currentIndex;
    if (forward) {
      if (current != null && current >= total - 1) {
        await searcher.goToMatchOfIndex(0);
      } else {
        await searcher.goToNextMatch();
      }
    } else {
      if (current != null && current <= 0) {
        await searcher.goToMatchOfIndex(total - 1);
      } else {
        await searcher.goToPrevMatch();
      }
    }
    if (mounted) setState(() {});
  }

  Widget _buildViewer() {
    final params = PdfViewerParams(
      // pdfrx's default sizing delegate overrides minScale with an auto-
      // computed "fit page" value. On the first frame the page number isn't
      // set yet, so that value falls back to coverScale (viewport / document
      // ratio), which can exceed maxScale on wide viewports and trip
      // InteractiveViewer's `maxScale >= minScale` assertion. Configure the
      // delegate explicitly with useAlternativeFitScaleAsMinScale: false so
      // the literal minScale is honored and the assertion always holds.
      sizeDelegateProvider: PdfViewerSizeDelegateProviderLegacy(
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        useAlternativeFitScaleAsMinScale: false,
      ),
      // pdfrx's default zoom-steps delegate can emit an unsorted list when
      // minScale falls between two power-of-two halvings of the fit-page
      // scale (it inserts minScale at index 0 even if a smaller value sits
      // at index 1). That makes the +/- buttons oscillate near the zoom-out
      // bound. Sort the stops to give the controller a monotonic list.
      zoomStepsDelegateProvider: const _SortedZoomStepsDelegateProvider(),
      pagePaintCallbacks: [_paintMatches],
      onViewerReady: (document, controller) {
        if (!mounted) return;
        _searcher ??= PdfTextSearcher(controller)..addListener(_onSearchUpdate);
        setState(() {
          _viewerReady = true;
          _pageCount = controller.pageCount;
          _currentPage = controller.pageNumber ?? 1;
        });
        widget.onDocumentLoaded?.call(controller.pageCount);
      },
      onPageChanged: (pageNumber) {
        if (!mounted || pageNumber == null) return;
        setState(() => _currentPage = pageNumber);
        widget.onPageChanged?.call(pageNumber);
      },
      errorBannerBuilder: widget.errorBuilder == null
          ? null
          : (context, error, stackTrace, documentRef) =>
                widget.errorBuilder!(context, error),
    );

    return switch (widget.source) {
      PdfUriSource(:final uri, :final headers) => PdfViewer.uri(
        uri,
        controller: _controller,
        params: params,
        headers: headers,
      ),
      PdfFileSource(:final path) => PdfViewer.file(
        path,
        controller: _controller,
        params: params,
      ),
      PdfBytesSource(:final bytes, :final sourceName) => PdfViewer.data(
        bytes,
        sourceName: sourceName ?? 'document.pdf',
        controller: _controller,
        params: params,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final showWebZoom = kIsWeb && widget.showZoomControlsOnWeb;
    return Column(
      children: [
        if (widget.enableSearch)
          _PdfSearchBar(
            controller: _searchInput,
            enabled: _viewerReady,
            onChanged: _onSearchChanged,
            onNext: (_searcher?.matches.isNotEmpty ?? false)
                ? () => _stepMatch(forward: true)
                : null,
            onPrev: (_searcher?.matches.isNotEmpty ?? false)
                ? () => _stepMatch(forward: false)
                : null,
            statusLabel: _searchStatusLabel(),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildViewer()),
              if (showWebZoom)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _PdfZoomControls(
                    onZoomIn: _viewerReady ? _controller.zoomUp : null,
                    onZoomOut: _viewerReady ? _controller.zoomDown : null,
                  ),
                ),
              if (widget.showPageIndicator && _viewerReady && _pageCount > 0)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: _PdfPageIndicator(
                    currentPage: _currentPage ?? 1,
                    pageCount: _pageCount,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _searchStatusLabel() {
    if (!_querySubmitted) return null;
    final searcher = _searcher;
    if (searcher == null) return null;
    final total = searcher.matches.length;
    if (total == 0) return 'No matches';
    final current = (searcher.currentIndex ?? 0) + 1;
    return '$current of $total';
  }
}

class _PdfSearchBar extends StatelessWidget {
  const _PdfSearchBar({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.statusLabel,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              // Rebuild on every keystroke so the Clear suffix appears/
              // disappears synchronously with input. The parent state only
              // rebuilds on debounce/search events, which would otherwise
              // leave the suffix stale until the next setState upstream.
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return TextField(
                    controller: controller,
                    enabled: enabled,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search in document',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                controller.clear();
                                onChanged('');
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            if (statusLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(statusLabel!, style: theme.textTheme.bodySmall),
              ),
            IconButton(
              tooltip: 'Previous match',
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: onPrev,
            ),
            IconButton(
              tooltip: 'Next match',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfZoomControls extends StatelessWidget {
  const _PdfZoomControls({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add),
            onPressed: onZoomIn,
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove),
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}

class _PdfPageIndicator extends StatelessWidget {
  const _PdfPageIndicator({required this.currentPage, required this.pageCount});

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.inverseSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Page $currentPage / $pageCount',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onInverseSurface,
        ),
      ),
    );
  }
}

class _SortedZoomStepsDelegateProvider
    extends PdfViewerZoomStepsDelegateProvider {
  const _SortedZoomStepsDelegateProvider();

  @override
  PdfViewerZoomStepsDelegate create() => _SortedZoomStepsDelegate();

  @override
  bool operator ==(Object other) => other is _SortedZoomStepsDelegateProvider;

  @override
  int get hashCode => runtimeType.hashCode;
}

class _SortedZoomStepsDelegate implements PdfViewerZoomStepsDelegate {
  final PdfViewerZoomStepsDelegateDefault _inner =
      PdfViewerZoomStepsDelegateDefault();

  @override
  void dispose() => _inner.dispose();

  // pdfrx's default delegate halves the fit-page scale until z > minScale is
  // false, but it inserts each halved value before re-checking, so the final
  // list contains a stop below minScale. The +/- buttons can then drive the
  // zoom below the gesture/InteractiveViewer minimum, leaving the button and
  // ctrl+scroll bounds inconsistent. Sort the stops and clip anything below
  // minScale (with a small tolerance) so all input methods bottom out at the
  // same value.
  @override
  List<double> generateZoomStops(PdfViewerLayoutMetrics metrics) {
    final raw = _inner.generateZoomStops(metrics);
    const epsilon = 0.001;
    final filtered = raw.where((z) => z >= metrics.minScale - epsilon).toList()
      ..sort();
    if (filtered.isEmpty) {
      return [metrics.minScale, metrics.maxScale];
    }
    if ((filtered.first - metrics.minScale).abs() > epsilon) {
      filtered.insert(0, metrics.minScale);
    }
    return filtered;
  }
}
