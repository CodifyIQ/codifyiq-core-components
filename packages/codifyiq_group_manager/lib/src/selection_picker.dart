import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'unsaved_changes_guard.dart';

/// One row offered by a [SelectionPicker].
typedef SelectionEntry = ({
  String id,
  String title,
  String? subtitle,
  Widget avatar,
});

/// The searchable, multi-select list body shared by [GroupPicker] and
/// [MemberPicker].
///
/// Internal: it exists so both public pickers behave identically — same search,
/// same locked semantics, same confirm-count wording, same adaptive chrome —
/// rather than drifting apart as two hand-maintained copies. Consumers use the
/// typed wrappers, which own the domain vocabulary ("groups" vs "members") and
/// build the [SelectionEntry] rows.
class SelectionPicker extends StatefulWidget {
  /// Creates a [SelectionPicker].
  const SelectionPicker({
    super.key,
    required this.entries,
    required this.searchHint,
    required this.noMatchesLabel,
    this.initiallySelected = const <String>{},
    this.lockedIds = const <String>{},
    this.title = 'Select',
    this.confirmLabel,
    this.destructive = false,
  });

  /// Every row the user may choose from, in display order.
  final List<SelectionEntry> entries;

  /// Placeholder for the search field, e.g. "Search groups".
  final String searchHint;

  /// Builds the empty-results message for a query, e.g.
  /// `(q) => 'No groups match "$q".'`.
  final String Function(String query) noMatchesLabel;

  /// Ids selected when the picker opens.
  final Set<String> initiallySelected;

  /// Ids that are always checked and cannot be unchecked.
  final Set<String> lockedIds;

  /// Heading shown at the top of the picker.
  final String title;

  /// Overrides the confirm button's default "Done (n)" label.
  final String? confirmLabel;

  /// Tints the checkboxes and confirm button with the error color.
  final bool destructive;

  /// M3 compact/medium breakpoint. Below this the picker is a bottom sheet; at
  /// or above it, a dialog.
  static const double _dialogBreakpoint = 600;

  /// Hosts [picker] in the adaptive chrome both public pickers share: a modal
  /// bottom sheet on compact widths (the M3 mobile pattern for a long,
  /// icon-and-description list) and a centered dialog at [_dialogBreakpoint]
  /// and wider, where a full-width bottom sheet anchored far from its trigger
  /// reads awkwardly. The body is identical in both — only the surface differs.
  static Future<Set<String>?> showAdaptive(
    BuildContext context, {
    required Widget picker,
  }) {
    final media = MediaQuery.of(context);
    // Host the picker on surfaceContainerLow so the surfaceContainerHigh search
    // bar inside it stays two tonal steps clear and never blends (M3 search:
    // keep container roles more than one step apart).
    final surface = Theme.of(context).colorScheme.surfaceContainerLow;

    if (media.size.width < _dialogBreakpoint) {
      return showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        // Drag-to-dismiss pops the route directly, so it would slip past the
        // picker's unsaved-selection guard; the drag handle stays draggable
        // even when enableDrag is false, so both are off. Dismissal goes
        // through the barrier, back gesture, or Cancel — all guarded.
        enableDrag: false,
        showDragHandle: false,
        backgroundColor: surface,
        builder: (_) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
            child: picker,
          ),
        ),
      );
    }

    return showDialog<Set<String>>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: surface,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
          child: SizedBox(width: 420, child: picker),
        ),
      ),
    );
  }

  @override
  State<SelectionPicker> createState() => _SelectionPickerState();
}

class _SelectionPickerState extends State<SelectionPicker> {
  late final Set<String> _selected = <String>{...widget.initiallySelected};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SelectionEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return widget.entries
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              (e.subtitle?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    // The picker always folds lockedIds back into its result, so count and
    // return against that union rather than the user-toggled set alone.
    final resolved = <String>{..._selected, ...widget.lockedIds};

    return UnsavedChangesGuard(
      hasChanges: !setEquals(_selected, widget.initiallySelected),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chrome (title, search, actions) is inset 16dp; the list is full-bleed
          // because CheckboxListTile applies its own 16dp, so rows line up with
          // the title rather than indenting an extra 16dp.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(widget.title, style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SearchBar(
              controller: _search,
              hintText: widget.searchHint,
              leading: const Icon(Icons.search),
              // M3 search: no shadow by default — the filled container, not
              // elevation, separates it. surfaceContainerHigh is the search
              // container role; it reads here because the surface behind it is
              // surfaceContainerLow (two steps clear).
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHigh,
              ),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: Text(
                      widget.noMatchesLabel(_query.trim()),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final isLocked = widget.lockedIds.contains(entry.id);
                      final checked = isLocked || _selected.contains(entry.id);
                      final tile = CheckboxListTile(
                        value: checked,
                        enabled: !isLocked,
                        activeColor: widget.destructive
                            ? theme.colorScheme.error
                            : null,
                        secondary: entry.avatar,
                        // A lock glyph beside the name marks the row as permanent,
                        // matching the locked chip and catalog cue — so the
                        // disabled checkbox doesn't read as merely unavailable.
                        title: isLocked
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(child: Text(entry.title)),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              )
                            : Text(entry.title),
                        subtitle: entry.subtitle == null
                            ? null
                            : Text(
                                entry.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onChanged: isLocked
                            ? null
                            : (value) => setState(() {
                                if (value ?? false) {
                                  _selected.add(entry.id);
                                } else {
                                  _selected.remove(entry.id);
                                }
                              }),
                      );
                      return isLocked
                          ? Tooltip(
                              message: 'Required — can\'t be removed',
                              child: tile,
                            )
                          : tile;
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            // OverflowBar (the same widget AlertDialog uses for its actions)
            // falls back to stacking the buttons vertically instead of
            // overflowing horizontally — a long confirmLabel (e.g. "Remove from
            // 128 users") can otherwise not fit next to "Cancel" on one line.
            child: OverflowBar(
              spacing: 8,
              overflowSpacing: 8,
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                TextButton(
                  // maybePop, not pop, so Cancel goes through the discard prompt
                  // too.
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: widget.destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        )
                      : null,
                  onPressed: () => Navigator.of(context).pop(resolved),
                  child: Text(
                    widget.confirmLabel ?? 'Done (${resolved.length})',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
