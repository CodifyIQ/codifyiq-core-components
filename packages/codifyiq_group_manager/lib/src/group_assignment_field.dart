import 'package:flutter/material.dart';

import 'group.dart';
import 'group_chip.dart';
import 'group_picker.dart';

/// A form field for assigning one or more groups to a target.
///
/// The target is anything your app authorizes — a user, but equally a folder,
/// document, project, or any other object. The widget is target-agnostic: it
/// only deals in the [groups] it may offer and the [selected] ids; the caller
/// decides what those groups are being attached to.
///
/// Renders the currently selected groups as removable [GroupChip]s, with a
/// stationary "Edit" button that opens a searchable [GroupPicker] of the
/// offered [groups]. The picker both adds and removes membership, so the
/// affordance reads "Edit" rather than "Add". Removing a chip or confirming
/// the picker reports the new selection through [onChanged].
///
/// Groups whose ids are in [lockedIds] always appear as non-removable chips
/// bearing a trailing lock glyph in place of the delete icon — even when they
/// are absent from [selected] — and are shown checked-and-disabled in the
/// picker. Every selection this field reports
/// through [onChanged], whether from the picker or from removing another chip,
/// includes [lockedIds], so a locked group can never be dropped. The field does
/// not mutate the caller-owned [selected]; if you persist that value, seed it
/// with the locked ids (or apply each [onChanged] update) to keep it in sync.
///
/// Only [selected] ids that are present in [groups] are rendered — the widget
/// has no [Group] data for ids outside the offered set, so it can neither show
/// nor remove them. When you scope [groups] to a subset (e.g. only the signed-in
/// user's own groups), keep it a superset of [selected], or reconcile the
/// selection when the offered set shrinks; otherwise a previously-assigned group
/// that drops out of [groups] becomes an invisible, unremovable assignment.
///
/// By default the label and edit button sit in their own header row, with
/// chips wrapping onto as many lines below as membership needs — good for a
/// single target on a form. Pass [maxVisibleChips] to cap how many of those
/// chips render before collapsing the rest behind a trailing "+N more" chip —
/// handy for a dense list of many targets (e.g. a bulk member list) where
/// showing every membership in full would make rows uneven and hard to scan.
///
/// For a grid-like list of many targets, set [singleLine] instead: the label,
/// chips, and edit button all share one row, and as many chips as fit the
/// available width are shown (further capped by [maxVisibleChips] if also
/// set), with the rest behind "+N more". The row always keeps room for the
/// "+N more" chip itself — an overlong [label] ellipsizes rather than
/// crowding it out too, though it's free to crowd out every *real* chip, down
/// to a row that's just the label and "+N more". Tapping "+N more" expands:
/// in the default stacked mode the chips simply wrap onto more lines, and in
/// [singleLine] mode the fitted row stays put while the overflow groups
/// appear in a second row below it — either way with a trailing "Show less"
/// chip to collapse again, and neither disturbing the chips already shown. The cap
/// only affects which chips are drawn — a group hidden behind "+N more" is
/// still assigned, still counted, and still shown (as locked or removable)
/// the moment the row expands.
///
/// This widget is value-driven and stateless with respect to membership — the
/// caller owns [selected] and applies updates in [onChanged]. Wire it to a
/// [GroupManagerController] from the caller, for example to assign groups to a
/// user:
///
/// ```dart
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) => GroupAssignmentField(
///     groups: controller.groups,
///     selected: controller.groupsFor(userId),
///     onChanged: (ids) => controller.setAssignments(userId, ids),
///   ),
/// );
/// ```
///
/// To attach groups to some other object — say, share a folder with only the
/// groups the signed-in user belongs to — offer that scoped subset and key the
/// assignment by the object's id:
///
/// ```dart
/// GroupAssignmentField(
///   groups: controller.resolvedGroupsFor(currentUserId), // only what I can grant
///   selected: controller.groupsFor('folder:$folderId'),
///   onChanged: (ids) => controller.setAssignments('folder:$folderId', ids),
/// );
/// ```
class GroupAssignmentField extends StatefulWidget {
  /// Creates a [GroupAssignmentField].
  const GroupAssignmentField({
    super.key,
    required this.groups,
    required this.selected,
    required this.onChanged,
    this.lockedIds = const <String>{},
    this.label,
    this.enabled = true,
    this.editLabel = 'Edit groups',
    this.editIcon = Icons.group_add_outlined,
    this.pickerTitle = 'Assign groups',
    this.emptyHint = 'No groups assigned',
    this.maxVisibleChips,
    this.singleLine = false,
  }) : assert(
         maxVisibleChips == null || maxVisibleChips > 0,
         'maxVisibleChips must be positive',
       );

  /// The groups that may be assigned to the target. Pass the full catalog, or a
  /// scoped subset (e.g. only the signed-in user's own groups) to limit choices.
  final List<Group> groups;

  /// Ids of the groups currently assigned to the target.
  final Set<String> selected;

  /// Called with the updated id set whenever the assignment changes.
  final ValueChanged<Set<String>> onChanged;

  /// Ids of groups that cannot be removed. These appear as non-removable chips
  /// and are checked-but-disabled in the picker.
  final Set<String> lockedIds;

  /// Optional label. Rendered above the chips by default, or inline to their
  /// left when [singleLine] is set.
  final String? label;

  /// Whether the field is interactive. When `false`, chips are read-only and
  /// the "Edit" affordance is hidden.
  final bool enabled;

  /// Tooltip for the header button that opens the picker. The picker both adds
  /// and removes membership, so this defaults to "Edit groups" rather than
  /// "Add" — pairing with the group-add [editIcon] without implying add-only.
  final String editLabel;

  /// Icon for the header button that opens the picker. Defaults to a group-add
  /// glyph; pass a more specific domain icon — e.g. a "manage user" glyph when
  /// assigning to a person, or an authorization glyph when granting access.
  final IconData editIcon;

  /// Title shown on the picker sheet.
  final String pickerTitle;

  /// Hint shown in place of the chips when nothing is assigned. When [enabled],
  /// the header's edit button remains available to add the first group.
  final String emptyHint;

  /// Caps how many chips render before the rest collapse behind a "+N more"
  /// chip. `null` (the default) shows every chip that otherwise fits — in
  /// [singleLine] mode that means "as many as the available width allows";
  /// in the default stacked mode it means "all of them". See the class doc
  /// for details.
  final int? maxVisibleChips;

  /// Lays the label, chips, and edit button out on a single row instead of a
  /// label row followed by a wrapped chip row — a denser, grid-like shape
  /// suited to a list of many targets. As many chips as fit the row's
  /// available width are shown; the rest collapse behind "+N more". See the
  /// class doc for details.
  final bool singleLine;

  @override
  State<GroupAssignmentField> createState() => _GroupAssignmentFieldState();
}

class _GroupAssignmentFieldState extends State<GroupAssignmentField> {
  bool _expanded = false;

  /// The groups to render as chips: everything in [GroupAssignmentField.selected],
  /// plus any [GroupAssignmentField.lockedIds] not already selected, so a
  /// locked group is always shown even when the caller hasn't seeded it into
  /// `selected`. Mirrors the picker, which always folds `lockedIds` back into
  /// its result.
  List<Group> get _selectedGroups => <Group>[
    for (final group in widget.groups)
      if (widget.selected.contains(group.id) ||
          widget.lockedIds.contains(group.id))
        group,
  ];

  Future<void> _openPicker(BuildContext context) async {
    final result = await GroupPicker.show(
      context,
      groups: widget.groups,
      initiallySelected: widget.selected,
      lockedIds: widget.lockedIds,
      title: widget.pickerTitle,
    );
    if (result != null) widget.onChanged(result);
  }

  void _remove(String id) {
    // Fold lockedIds back in so removing a chip can never drop a locked group,
    // matching the picker. id is always an unlocked group (locked chips have no
    // delete affordance), so the union never re-adds the id being removed.
    widget.onChanged(
      <String>{...widget.selected, ...widget.lockedIds}..remove(id),
    );
  }

  Widget _chip(Group group) => widget.lockedIds.contains(group.id)
      ? GroupChip(group: group, locked: true)
      : GroupChip(
          group: group,
          onDeleted: widget.enabled ? () => _remove(group.id) : null,
        );

  Widget _editButton(BuildContext context) => IconButton(
    icon: Icon(widget.editIcon),
    tooltip: widget.editLabel,
    onPressed: () => _openPicker(context),
  );

  @override
  Widget build(BuildContext context) {
    return widget.singleLine
        ? _buildSingleLine(context)
        : _buildStacked(context);
  }

  Widget _buildStacked(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGroups = _selectedGroups;
    final cap = widget.maxVisibleChips;
    final collapsed = cap != null && !_expanded && selectedGroups.length > cap;
    final visibleGroups = collapsed
        ? selectedGroups.take(cap).toList()
        : selectedGroups;
    final hiddenCount = selectedGroups.length - visibleGroups.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The label and edit trigger share a fixed header row, so the trigger
        // stays anchored instead of drifting to the end of the chip flow as
        // membership changes.
        if (widget.label != null || widget.enabled) ...[
          Row(
            children: [
              if (widget.label != null)
                Expanded(
                  child: Text(
                    widget.label!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (widget.enabled) _editButton(context),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (selectedGroups.isEmpty)
          Text(
            widget.emptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final group in visibleGroups) _chip(group),
              if (hiddenCount > 0)
                ActionChip(
                  label: Text('+$hiddenCount more'),
                  onPressed: () => setState(() => _expanded = true),
                ),
              if (_expanded && cap != null && selectedGroups.length > cap)
                ActionChip(
                  label: const Text('Show less'),
                  onPressed: () => setState(() => _expanded = false),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSingleLine(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGroups = _selectedGroups;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for at least one chip (plus an overflow chip, if there
        // would be one) before sizing the label, so a long name can never
        // squeeze every chip out of the row — it ellipsizes instead.
        const editButtonWidth = 48.0;
        const labelGap = 12.0;
        final editWidth = widget.enabled ? editButtonWidth : 0.0;
        final minChipsWidth = _minChipsWidth(context, selectedGroups);
        final labelGapWidth = widget.label != null ? labelGap : 0.0;
        final labelMaxWidth = widget.label == null
            ? 0.0
            : (constraints.maxWidth - editWidth - labelGapWidth - minChipsWidth)
                  .clamp(0.0, double.infinity);
        // The label ellipsizes to at most labelMaxWidth, so its rendered width
        // is that or its intrinsic width, whichever is smaller — enough to
        // estimate what's left for the chip flow without a nested layout pass.
        final labelWidth = widget.label == null
            ? 0.0
            : _textWidth(
                context,
                widget.label!,
              ).clamp(0.0, labelMaxWidth);
        final chipAreaWidth =
            (constraints.maxWidth - editWidth - labelWidth - labelGapWidth)
                .clamp(0.0, double.infinity);

        var fitted = _fitChips(context, selectedGroups, chipAreaWidth);
        final cap = widget.maxVisibleChips;
        if (cap != null && fitted.visible.length > cap) {
          fitted = (
            visible: fitted.visible.take(cap).toList(),
            hiddenCount: fitted.hiddenCount + (fitted.visible.length - cap),
          );
        }
        final hiddenGroups = selectedGroups
            .skip(fitted.visible.length)
            .toList();

        // The single row that stays put whether or not the field is expanded:
        // the label, the chips that fit, and the edit trigger. Overflow shows
        // as a "+N more" chip when collapsed; expanding moves it to a second
        // row instead, so the chips already on screen never shift.
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.label != null) ...[
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: labelMaxWidth),
                child: Text(
                  widget.label!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: labelGap),
            ],
            Expanded(
              child: selectedGroups.isEmpty
                  ? Text(
                      widget.emptyHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final group in fitted.visible) _chip(group),
                        if (!_expanded && fitted.hiddenCount > 0)
                          ActionChip(
                            label: Text('+${fitted.hiddenCount} more'),
                            onPressed: () => setState(() => _expanded = true),
                          ),
                      ],
                    ),
            ),
            if (widget.enabled) _editButton(context),
          ],
        );

        if (!_expanded || hiddenGroups.isEmpty) return row;

        // Expanded: leave the row above exactly as it was and append a second
        // row with the groups that didn't fit, wrapping onto as many lines as
        // needed, plus a "Show less" affordance to collapse back.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row,
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final group in hiddenGroups) _chip(group),
                ActionChip(
                  label: const Text('Show less'),
                  onPressed: () => setState(() => _expanded = false),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// The narrowest the chip area can be while still showing the "+N more"
  /// overflow chip on its own — worst case, every group is hidden behind it.
  /// [_buildSingleLine] caps the label to whatever width is left over after
  /// this, so an overlong label ellipsizes instead of squeezing the row down
  /// to nothing at all. It's fine for a long label to push every real chip
  /// out in favor of just the overflow chip — see [_fitChips].
  double _minChipsWidth(BuildContext context, List<Group> groups) {
    if (groups.isEmpty) return 0;
    return _estimateOverflowChipWidth(context, groups.length);
  }

  /// Estimates how many leading [groups] fit within [maxWidth] on a single
  /// line, reserving room for a trailing "+N more" chip when not all of them
  /// do. Chip widths are estimated from label text metrics rather than a real
  /// layout pass — close enough to size the row without the cost (and
  /// complexity) of rendering twice; being off by a chip's width in either
  /// direction is an acceptable trade-off for a density heuristic.
  ({List<Group> visible, int hiddenCount}) _fitChips(
    BuildContext context,
    List<Group> groups,
    double maxWidth,
  ) {
    const spacing = 8.0;
    final widths = [
      for (final group in groups)
        _estimateChipWidth(
          context,
          group.name,
          removable: widget.enabled && !widget.lockedIds.contains(group.id),
        ),
    ];

    var total = 0.0;
    for (var i = 0; i < widths.length; i++) {
      total += widths[i] + (i == 0 ? 0 : spacing);
    }
    if (total <= maxWidth) return (visible: groups, hiddenCount: 0);

    var used = 0.0;
    var count = 0;
    for (var i = 0; i < groups.length; i++) {
      final next = used + (count == 0 ? 0 : spacing) + widths[i];
      final overflowWidth = _estimateOverflowChipWidth(
        context,
        groups.length - (count + 1),
      );
      if (next + spacing + overflowWidth > maxWidth) break;
      used = next;
      count++;
    }
    // Zero is a legitimate outcome here — an extremely narrow row (or a long
    // label crowding the chip area, see _minChipsWidth) shows just the
    // overflow chip rather than clipping a real one.
    count = count.clamp(0, groups.length);
    return (
      visible: groups.take(count).toList(),
      hiddenCount: groups.length - count,
    );
  }

  double _estimateChipWidth(
    BuildContext context,
    String label, {
    required bool removable,
  }) {
    // M3 chip chrome this approximates: a 24dp avatar plus its gap to the
    // label, ~12dp label padding on each side, and — when removable — a
    // trailing delete icon plus its gap.
    const avatarAndGap = 32.0;
    const labelPadding = 24.0;
    const deleteAffordance = 26.0;
    return avatarAndGap +
        labelPadding +
        _textWidth(context, label) +
        (removable ? deleteAffordance : 0);
  }

  double _estimateOverflowChipWidth(BuildContext context, int hiddenCount) {
    const labelPadding = 24.0;
    return labelPadding + _textWidth(context, '+$hiddenCount more');
  }

  double _textWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: Theme.of(context).textTheme.labelLarge),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}
