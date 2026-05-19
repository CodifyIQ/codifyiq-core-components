import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'chat_history_item.dart';

const double _kDefaultWidth = 280.0;
const double _kCollapsedWidth = 56.0;
const int _kSkeletonCount = 6;

// Row layout dimensions shared by _ChatRow and _SkeletonRow so the skeleton
// stays pixel-aligned with the real content if the indicator size changes.
const double _kRowHorizontalPadding = 12.0;
const double _kIndicatorWidth = 3.0;
const double _kIndicatorMarginRight = 8.0;
const double _kRowContentOffset =
    _kRowHorizontalPadding + _kIndicatorWidth + _kIndicatorMarginRight;

String _relativeTime(DateTime updatedAt) {
  final now = DateTime.now();
  final diff = now.difference(updatedAt);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = months[updatedAt.month - 1];
  return updatedAt.year == now.year
      ? '$month ${updatedAt.day}'
      : '$month ${updatedAt.day}, ${updatedAt.year}';
}

/// A fixed-width sidebar listing chat conversations with live search.
///
/// Renders a searchable, scrollable list of [ChatHistoryItem]s sorted by
/// [ChatHistoryItem.updatedAt] descending. Handles loading (shimmer
/// skeletons), empty, and error states. Provides a collapsible icon-strip
/// mode suitable for narrow viewports.
///
/// The sidebar owns its search state internally. Callers supply [chats],
/// [activeChatId], and [onChatSelected]; all other parameters are optional.
///
/// ## Layout — side-by-side
///
/// Place the sidebar in a [Row] to push content to the right:
///
/// ```dart
/// Row(
///   children: [
///     ChatHistorySidebar(
///       chats: myChats,
///       activeChatId: selectedId,
///       onChatSelected: (chat) => setState(() => selectedId = chat.id),
///     ),
///     const VerticalDivider(width: 1),
///     Expanded(child: MyChatView(chatId: selectedId)),
///   ],
/// )
/// ```
///
/// ## Layout — floating overlay
///
/// Place the sidebar in a [Stack] so it floats over the content without
/// affecting its width. Manage the open/closed state externally:
///
/// ```dart
/// Stack(
///   children: [
///     Positioned.fill(child: MyChatView(chatId: selectedId)),
///     if (_open)
///       Positioned(
///         top: 0, left: 0, bottom: 0,
///         child: ChatHistorySidebar(
///           chats: myChats,
///           activeChatId: selectedId,
///           onChatSelected: ...,
///           onToggleCollapse: () => setState(() => _open = false),
///         ),
///       )
///     else
///       Positioned(
///         top: 8, left: 8,
///         child: IconButton(
///           icon: const Icon(Icons.menu),
///           onPressed: () => setState(() => _open = true),
///         ),
///       ),
///   ],
/// )
/// ```
///
/// ## Collapsible mode (built-in)
///
/// Alternatively, toggle [isCollapsed] to switch the sidebar to a 56 dp
/// icon strip. Best suited for the side-by-side layout where [isCollapsed]
/// animates with [AnimatedSize]:
///
/// ```dart
/// ChatHistorySidebar(
///   chats: myChats,
///   onChatSelected: _onSelect,
///   isCollapsed: _collapsed,
///   onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
/// )
/// ```
class ChatHistorySidebar extends StatefulWidget {
  /// Creates a [ChatHistorySidebar].
  ///
  /// [chats] is the full conversation list. [onChatSelected] fires when the
  /// user clicks or presses Enter on a row.
  const ChatHistorySidebar({
    super.key,
    required this.chats,
    required this.onChatSelected,
    this.activeChatId,
    this.width = _kDefaultWidth,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    this.searchDebounceMs = 300,
    this.showTimestamps = true,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.onNewChat,
    this.emptyPlaceholder,
    this.headerTitle = 'Conversations',
  });

  /// Full list of conversations to display.
  ///
  /// The sidebar sorts this list by [ChatHistoryItem.updatedAt] descending,
  /// so the order provided here does not matter.
  final List<ChatHistoryItem> chats;

  /// Called when the user selects a conversation.
  final ValueChanged<ChatHistoryItem> onChatSelected;

  /// ID of the currently active conversation.
  ///
  /// The matching row is highlighted and scrolled into view when it changes.
  final String? activeChatId;

  /// Width of the expanded sidebar in logical pixels. Defaults to 280.
  ///
  /// Ignored when [isCollapsed] is `true`.
  final double width;

  /// When `true`, displays shimmer skeleton rows instead of the chat list.
  final bool isLoading;

  /// When `true`, displays the error state.
  final bool hasError;

  /// Error message shown in the error state.
  ///
  /// Defaults to "Could not load conversations" when `null`.
  final String? errorMessage;

  /// Callback rendered as a Retry button in the error state.
  final VoidCallback? onRetry;

  /// Debounce delay in milliseconds for the search input. Defaults to 300.
  ///
  /// Set to 0 to filter synchronously on every keystroke.
  final int searchDebounceMs;

  /// Whether to display relative timestamps beneath each chat title.
  ///
  /// Defaults to `true`.
  final bool showTimestamps;

  /// Whether the sidebar renders in collapsed (56 dp icon-strip) mode.
  final bool isCollapsed;

  /// Called when the user taps the collapse / expand toggle button.
  ///
  /// The caller owns [isCollapsed]; this callback signals an intent to toggle.
  /// When `null`, no toggle button is shown.
  final VoidCallback? onToggleCollapse;

  /// Called when the user taps the new-chat button in the sidebar header.
  ///
  /// When `null`, no new-chat button is shown.
  final VoidCallback? onNewChat;

  /// Widget shown when the filtered list is empty.
  ///
  /// Defaults to an icon and "No conversations yet" message.
  final Widget? emptyPlaceholder;

  /// Title text displayed at the top of the expanded sidebar.
  ///
  /// Defaults to "Conversations".
  final String headerTitle;

  @override
  State<ChatHistorySidebar> createState() => _ChatHistorySidebarState();
}

class _ChatHistorySidebarState extends State<ChatHistorySidebar> {
  late final TextEditingController _searchController;
  late List<ChatHistoryItem> _sortedChats;
  late List<ChatHistoryItem> _filteredChats;

  // Used by Scrollable.ensureVisible to keep the active row visible.
  final GlobalKey _activeItemKey = GlobalKey();

  Timer? _debounce;
  Timer? _timestampRefresh;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _sortedChats = _sort(widget.chats);
    _filteredChats = _sortedChats;
    _timestampRefresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ChatHistorySidebar old) {
    super.didUpdateWidget(old);
    final chatsChanged = !identical(widget.chats, old.chats) &&
        !listEquals(widget.chats, old.chats);
    if (chatsChanged) {
      _sortedChats = _sort(widget.chats);
      _applyFilter();
    }
    if (widget.activeChatId != old.activeChatId || chatsChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _activeItemKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _timestampRefresh?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<ChatHistoryItem> _sort(List<ChatHistoryItem> chats) {
    final sorted = List<ChatHistoryItem>.of(chats)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  void _applyFilter() {
    _filteredChats = _query.isEmpty
        ? _sortedChats
        : _sortedChats
            .where((c) => c.title.toLowerCase().contains(_query))
            .toList();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    if (widget.searchDebounceMs == 0) {
      setState(() {
        _query = text.toLowerCase();
        _applyFilter();
      });
    } else {
      _debounce = Timer(Duration(milliseconds: widget.searchDebounceMs), () {
        if (!mounted) return;
        setState(() {
          _query = text.toLowerCase();
          _applyFilter();
        });
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _filteredChats = _sortedChats;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return _CollapsedStrip(onToggleCollapse: widget.onToggleCollapse);
    }

    final theme = Theme.of(context);
    return SizedBox(
      width: widget.width,
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            _buildSearchField(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.headerTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (widget.onNewChat != null)
            IconButton(
              icon: const Icon(Icons.edit_square),
              tooltip: 'New conversation',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onNewChat,
            ),
          if (widget.onToggleCollapse != null)
            IconButton(
              icon: const Icon(Icons.menu_open),
              tooltip: 'Collapse sidebar',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onToggleCollapse,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return ListenableBuilder(
      listenable: _searchController,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) return const _SkeletonList();
    if (widget.hasError) {
      return _ErrorState(
        message: widget.errorMessage,
        onRetry: widget.onRetry,
      );
    }
    if (_filteredChats.isEmpty) {
      return widget.emptyPlaceholder ?? _EmptyState(hasQuery: _query.isNotEmpty);
    }
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _filteredChats.length,
        itemBuilder: (context, index) {
          final chat = _filteredChats[index];
          final isActive = chat.id == widget.activeChatId;
          return _ChatRow(
            key: ValueKey(chat.id),
            rowKey: isActive ? _activeItemKey : null,
            chat: chat,
            isActive: isActive,
            showTimestamp: widget.showTimestamps,
            onTap: () => widget.onChatSelected(chat),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsed strip
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsedStrip extends StatelessWidget {
  const _CollapsedStrip({this.onToggleCollapse});

  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _kCollapsedWidth,
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            const SizedBox(height: 12),
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Expand sidebar',
              onPressed: onToggleCollapse,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat row
// ─────────────────────────────────────────────────────────────────────────────

class _ChatRow extends StatefulWidget {
  const _ChatRow({
    super.key,
    this.rowKey,
    required this.chat,
    required this.isActive,
    required this.showTimestamp,
    required this.onTap,
  });

  final Key? rowKey;
  final ChatHistoryItem chat;
  final bool isActive;
  final bool showTimestamp;
  final VoidCallback onTap;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final backgroundColor = widget.isActive
        ? cs.secondaryContainer
        : _isHovered
            ? cs.surfaceContainerHigh
            : Colors.transparent;

    final titleColor =
        widget.isActive ? cs.onSecondaryContainer : cs.onSurface;
    final timestampColor = widget.isActive
        ? cs.onSecondaryContainer.withValues(alpha: 0.7)
        : cs.onSurfaceVariant;

    return Semantics(
      label: widget.chat.title,
      selected: widget.isActive,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          // KeyedSubtree carries the GlobalKey so Scrollable.ensureVisible
          // works without keying the Semantics widget (which would remount
          // _ChatRowState and reset hover state on every active-chat change).
          child: KeyedSubtree(
            key: widget.rowKey,
            child: Ink(
              color: backgroundColor,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kRowHorizontalPadding,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Left-edge indicator bar for active item.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _kIndicatorWidth,
                        height: 36,
                        margin: const EdgeInsets.only(right: _kIndicatorMarginRight),
                        decoration: BoxDecoration(
                          color: widget.isActive
                              ? cs.secondary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chat.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: widget.isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.showTimestamp) ...[
                            const SizedBox(height: 2),
                            Text(
                              _relativeTime(widget.chat.updatedAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: timestampColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kSkeletonCount,
      itemBuilder: (context, i) => const _SkeletonRow(),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kRowContentOffset,
          10,
          _kRowHorizontalPadding,
          10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 10,
              width: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.chat_bubble_outline,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'No conversations match'
                  : 'No conversations yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Could not load conversations',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
