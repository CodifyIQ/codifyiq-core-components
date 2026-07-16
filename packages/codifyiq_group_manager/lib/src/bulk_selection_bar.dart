import 'package:flutter/material.dart';

/// Options offered by [BulkSelectionBar]'s selection dropdown.
enum BulkSelectAll { all, none }

/// A fixed-height selection toolbar for a list that supports bulk actions.
///
/// Leads with a Gmail-style selector — a tristate checkbox (checked when
/// every visible row is selected, indeterminate when some are, unchecked
/// otherwise) paired with a dropdown offering "All"/"None" explicitly, so the
/// tristate look always has an obvious "select everything" affordance — plus
/// a running count. [actions] (e.g. icon buttons for bulk operations) are
/// hidden — not just disabled — until [selectedCount] is non-zero, but the
/// space they occupy is always reserved via [Visibility.maintainSize], so
/// starting or clearing a selection never reflows the list below.
///
/// The caller owns selection state entirely; this widget only reports intent
/// through [onSelectAll] with which of [BulkSelectAll.all] or
/// [BulkSelectAll.none] was chosen. It has no dependency on [Group] or
/// [GroupManagerController] — pair it with any list, keyed by whatever ids
/// the caller is tracking:
///
/// ```dart
/// BulkSelectionBar(
///   selectedCount: selectedIds.length,
///   allVisibleSelected: visibleUsers.isNotEmpty &&
///       visibleUsers.every((u) => selectedIds.contains(u.id)),
///   onSelectAll: (choice) => setState(() {
///     if (choice == BulkSelectAll.all) {
///       selectedIds.addAll(visibleUsers.map((u) => u.id));
///     } else {
///       selectedIds.clear();
///     }
///   }),
///   actions: [
///     IconButton(
///       tooltip: 'Add groups',
///       onPressed: () => bulkAssign(context),
///       icon: const Icon(Icons.group_add_outlined),
///     ),
///   ],
/// );
/// ```
class BulkSelectionBar extends StatelessWidget {
  /// Creates a [BulkSelectionBar].
  const BulkSelectionBar({
    super.key,
    required this.selectedCount,
    required this.allVisibleSelected,
    required this.onSelectAll,
    this.actions = const <Widget>[],
    this.emptyLabel = 'No items selected',
    this.leadingBoxSize = 40.0,
  });

  /// Number of currently selected items.
  final int selectedCount;

  /// Whether every currently visible (e.g. search-filtered) item is
  /// selected. Drives the checkbox's checked/indeterminate state.
  final bool allVisibleSelected;

  /// Called with [BulkSelectAll.all] or [BulkSelectAll.none] when the
  /// checkbox or the dropdown menu is used to change the selection scope.
  final ValueChanged<BulkSelectAll> onSelectAll;

  /// Bulk-action widgets (e.g. [IconButton]s) shown once [selectedCount] is
  /// non-zero. Their layout space is always reserved.
  final List<Widget> actions;

  /// Label shown when nothing is selected.
  final String emptyLabel;

  /// Size of the box the selector checkbox is centered in.
  ///
  /// Match this to the leading control's size in the list below (e.g.
  /// `SelectableAvatarLeading.radius * 2` from `codifyiq_user_avatar`) so the
  /// checkbox lines up with each row's own leading control rather than just
  /// defaulting to this widget's own idea of a typical row height.
  final double leadingBoxSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuAnchor(
              menuChildren: [
                MenuItemButton(
                  onPressed: () => onSelectAll(BulkSelectAll.all),
                  child: const Text('All'),
                ),
                MenuItemButton(
                  onPressed: () => onSelectAll(BulkSelectAll.none),
                  child: const Text('None'),
                ),
              ],
              builder: (context, controller, child) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: leadingBoxSize,
                    height: leadingBoxSize,
                    child: Checkbox(
                      tristate: true,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: selectedCount == 0
                          ? false
                          : (allVisibleSelected ? true : null),
                      onChanged: (_) => onSelectAll(
                        allVisibleSelected
                            ? BulkSelectAll.none
                            : BulkSelectAll.all,
                      ),
                    ),
                  ),
                  // Centering the checkbox in its leadingBoxSize box (so it
                  // lines up with each row's leading control) leaves dead space
                  // to its right. The checkbox glyph is a fixed 18dp square, so
                  // its right edge sits at leadingBoxSize / 2 + 9; shift the
                  // dropdown back by the gap between there and the box edge so
                  // the two hug as a single control.
                  Transform.translate(
                    offset: Offset(9 - leadingBoxSize / 2, 0),
                    child: IconButton(
                      tooltip: 'Selection options',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.arrow_drop_down),
                      onPressed: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              selectedCount == 0 ? emptyLabel : '$selectedCount selected',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        Visibility(
          visible: selectedCount > 0,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Row(mainAxisSize: MainAxisSize.min, children: actions),
        ),
      ],
    );
  }
}
