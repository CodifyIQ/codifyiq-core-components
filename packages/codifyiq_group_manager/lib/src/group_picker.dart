import 'package:flutter/material.dart';

import 'group.dart';
import 'group_avatar.dart';

/// A searchable, multi-select picker for choosing groups.
///
/// Presentational and value-driven: it takes the full [groups] catalog and the
/// [initiallySelected] ids, and resolves with the updated selection when the
/// user confirms — or `null` if they dismiss it. It performs no persistence.
///
/// Groups whose ids are in [lockedIds] appear checked and disabled, with a lock
/// glyph beside the name (tooltip: "Required — can't be removed") — the user
/// cannot uncheck them. They are always included in the resolved selection.
///
/// [show] presents the picker **adaptively**, following Material 3's
/// large-screen guidance: a modal bottom sheet on compact widths (the M3 mobile
/// pattern for a long, icon-and-description list) and a centered dialog at
/// `600dp` and wider, where a full-width bottom sheet anchored far from its
/// trigger reads awkwardly. The widget body is identical in both — only the
/// surrounding surface differs.
///
/// Used by [GroupAssignmentField] for its "Add" affordance, but also usable on
/// its own.
class GroupPicker extends StatefulWidget {
  /// Creates a [GroupPicker].
  const GroupPicker({
    super.key,
    required this.groups,
    this.initiallySelected = const <String>{},
    this.lockedIds = const <String>{},
    this.title = 'Select groups',
    this.confirmLabel,
    this.destructive = false,
  });

  /// Every group the user may choose from.
  final List<Group> groups;

  /// Ids selected when the picker opens.
  final Set<String> initiallySelected;

  /// Ids that are always checked and cannot be unchecked.
  final Set<String> lockedIds;

  /// Heading shown at the top of the picker.
  final String title;

  /// Overrides the confirm button's default "Done (n)" label, where `n` is
  /// the selected count. Useful when the picker is framing a different action
  /// than "select these groups" — e.g. [GroupBulkAssignmentDialog] uses this
  /// to read "Add to 12 users" instead.
  final String? confirmLabel;

  /// Tints the checkboxes and confirm button with the error color instead of
  /// the usual primary/secondary role.
  ///
  /// Checking a box here normally means "select this group" — read as
  /// affirmative in every other use of this picker. Set this when checking a
  /// box instead means the opposite, e.g. "mark this group for removal" (see
  /// [GroupBulkAssignmentDialog.showRemoval]), so the reversed meaning has a
  /// visual cue beyond the title and button text.
  final bool destructive;

  /// M3 compact/medium breakpoint. Below this the picker is a bottom sheet; at
  /// or above it, a dialog.
  static const double _dialogBreakpoint = 600;

  /// Shows the picker adaptively and resolves with the chosen ids, or `null` if
  /// dismissed.
  ///
  /// Presents a modal bottom sheet on compact widths and a dialog at
  /// [_dialogBreakpoint] and wider.
  static Future<Set<String>?> show(
    BuildContext context, {
    required List<Group> groups,
    Set<String> initiallySelected = const <String>{},
    Set<String> lockedIds = const <String>{},
    String title = 'Select groups',
    String? confirmLabel,
    bool destructive = false,
  }) {
    final media = MediaQuery.of(context);
    // Host the picker on surfaceContainerLow so the surfaceContainerHigh search
    // bar inside it stays two tonal steps clear and never blends (M3 search:
    // keep container roles more than one step apart).
    final surface = Theme.of(context).colorScheme.surfaceContainerLow;
    final picker = GroupPicker(
      groups: groups,
      initiallySelected: initiallySelected,
      lockedIds: lockedIds,
      title: title,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );

    if (media.size.width < _dialogBreakpoint) {
      return showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
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
  State<GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<GroupPicker> {
  late final Set<String> _selected = <String>{...widget.initiallySelected};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Group> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.groups;
    return widget.groups
        .where(
          (g) =>
              g.name.toLowerCase().contains(q) ||
              (g.description?.toLowerCase().contains(q) ?? false),
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

    return Column(
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
            hintText: 'Search groups',
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
                    'No groups match "${_query.trim()}".',
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
                    final group = filtered[index];
                    final isLocked = widget.lockedIds.contains(group.id);
                    final checked = isLocked || _selected.contains(group.id);
                    final tile = CheckboxListTile(
                      value: checked,
                      enabled: !isLocked,
                      activeColor: widget.destructive
                          ? theme.colorScheme.error
                          : null,
                      secondary: GroupAvatar(group: group),
                      // A lock glyph beside the name marks the row as permanent,
                      // matching the locked chip and catalog cue — so the
                      // disabled checkbox doesn't read as merely unavailable.
                      title: isLocked
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(child: Text(group.name)),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            )
                          : Text(group.name),
                      subtitle: group.description == null
                          ? null
                          : Text(
                              group.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onChanged: isLocked
                          ? null
                          : (value) => setState(() {
                              if (value ?? false) {
                                _selected.add(group.id);
                              } else {
                                _selected.remove(group.id);
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
                onPressed: () => Navigator.of(context).pop(),
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
                child: Text(widget.confirmLabel ?? 'Done (${resolved.length})'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
