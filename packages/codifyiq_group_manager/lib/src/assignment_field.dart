import 'package:flutter/material.dart';

import 'assignment_role.dart';
import 'role_menu.dart';

/// One chip the field can render, reduced to what the layout needs: an id to
/// key on, and the label and resolved role label (if any) to measure.
typedef AssignmentEntry = ({String id, String label, String? roleLabel});

/// Builds the chip for [id], already told whether it is locked, how to remove
/// it (when it is not locked), the role label to show (if any), and how to open
/// the role menu (when the role can change).
typedef AssignmentChipBuilder =
    Widget Function(
      String id, {
      required bool locked,
      VoidCallback? onDeleted,
      String? roleLabel,
      VoidCallback? onRolePressed,
    });

/// Resolves the role label for [id]: `null` when roles are off or [id] has no
/// entry in [rolesById]; the matching [AssignmentRole.label] when there is one;
/// otherwise the raw role id, so an unknown role still shows something.
String? resolveRoleLabel(
  List<AssignmentRole> roles,
  Map<String, String> rolesById,
  String id,
) {
  if (roles.isEmpty) return null;
  final roleId = rolesById[id];
  if (roleId == null) return null;
  for (final role in roles) {
    if (role.id == roleId) return role.label;
  }
  return roleId;
}

/// The chips-plus-edit-button layout shared by [GroupAssignmentField] and
/// [MemberAssignmentField].
///
/// Internal: it owns the expand/collapse state and the single-line fitting
/// math, so both public fields lay out identically instead of drifting apart as
/// two hand-maintained copies of some fairly delicate width arithmetic.
/// Consumers use the typed wrappers, which own the domain vocabulary (groups
/// vs members), build the chips, and open the matching picker.
class AssignmentField extends StatefulWidget {
  /// Creates an [AssignmentField].
  const AssignmentField({
    super.key,
    required this.entries,
    required this.selected,
    required this.onChanged,
    required this.chipBuilder,
    required this.openPicker,
    this.lockedIds = const <String>{},
    this.label,
    this.enabled = true,
    this.editLabel = 'Edit',
    this.editIcon = Icons.edit_outlined,
    this.emptyHint = 'Nothing assigned',
    this.maxVisibleChips,
    this.singleLine = false,
    required this.sizeAnimationDuration,
    this.roles = const <AssignmentRole>[],
    this.rolesById = const <String, String>{},
    this.defaultRoleId,
    this.onRoleChanged,
  }) : assert(
         maxVisibleChips == null || maxVisibleChips > 0,
         'maxVisibleChips must be positive',
       );

  /// Everything that may be assigned, in display order.
  final List<AssignmentEntry> entries;

  /// Ids currently assigned.
  final Set<String> selected;

  /// Called with the updated id set whenever the assignment changes.
  final ValueChanged<Set<String>> onChanged;

  /// Builds each chip.
  final AssignmentChipBuilder chipBuilder;

  /// Opens the picker and resolves with the new selection, or `null` if the
  /// user dismissed it.
  final Future<Set<String>?> Function(BuildContext context) openPicker;

  /// Ids that cannot be removed.
  final Set<String> lockedIds;

  /// Optional label. Rendered above the chips by default, or inline to their
  /// left when [singleLine] is set.
  final String? label;

  /// Whether the field is interactive.
  final bool enabled;

  /// Tooltip for the header button that opens the picker.
  final String editLabel;

  /// Icon for the header button that opens the picker.
  final IconData editIcon;

  /// Hint shown in place of the chips when nothing is assigned.
  final String emptyHint;

  /// Caps how many chips render before the rest collapse behind "+N more".
  final int? maxVisibleChips;

  /// Lays the label, chips, and edit button out on a single row.
  final bool singleLine;

  /// How long the field takes to grow or shrink when its chips change.
  /// [Duration.zero] resizes instantly.
  final Duration sizeAnimationDuration;

  /// Roles an assignment may carry. Empty turns the role feature off.
  final List<AssignmentRole> roles;

  /// Current role id per selected id. A selected id with no entry shows no
  /// role but still offers the menu.
  final Map<String, String> rolesById;

  /// Role reported through [onRoleChanged] for each id the picker adds. `null`
  /// leaves new ids role-less until the user picks one from the chip.
  final String? defaultRoleId;

  /// Called when an id's role changes, from the role menu or a picker add.
  /// Picker adds are reported for every id the picker added, whether or not
  /// the caller kept it in [onChanged].
  final void Function(String id, String roleId)? onRoleChanged;

  @override
  State<AssignmentField> createState() => _AssignmentFieldState();
}

class _AssignmentFieldState extends State<AssignmentField> {
  bool _expanded = false;

  /// The entries to render as chips: everything in [AssignmentField.selected],
  /// plus any [AssignmentField.lockedIds] not already selected, so a locked
  /// entry is always shown even when the caller hasn't seeded it into
  /// `selected`. Mirrors the picker, which always folds `lockedIds` back into
  /// its result.
  List<AssignmentEntry> get _selectedEntries => <AssignmentEntry>[
    for (final entry in widget.entries)
      if (widget.selected.contains(entry.id) ||
          widget.lockedIds.contains(entry.id))
        entry,
  ];

  Future<void> _openPicker(BuildContext context) async {
    // Snapshot before awaiting: the widget may rebuild with a new selection
    // while the picker is open.
    final before = <String>{...widget.selected, ...widget.lockedIds};
    final result = await widget.openPicker(context);
    if (result == null || !mounted) return;
    widget.onChanged(result);

    // The field never stores roles: it reports the default role for each id
    // the picker added and leaves the caller to record it. It can't see what
    // the caller kept in onChanged, so a caller that filters the selection
    // should ignore role reports for ids it dropped.
    final defaultRoleId = widget.defaultRoleId;
    final onRoleChanged = widget.onRoleChanged;
    if (widget.roles.isEmpty ||
        defaultRoleId == null ||
        onRoleChanged == null) {
      return;
    }
    for (final id in result) {
      if (!before.contains(id)) onRoleChanged(id, defaultRoleId);
    }
  }

  void _remove(String id) {
    // Fold lockedIds back in so removing a chip can never drop a locked entry,
    // matching the picker. id is always an unlocked entry (locked chips have no
    // delete affordance), so the union never re-adds the id being removed.
    widget.onChanged(
      <String>{...widget.selected, ...widget.lockedIds}..remove(id),
    );
  }

  /// Whether [entry]'s role can be changed from its chip: roles are on and
  /// reported, and the chip is neither locked nor disabled. An entry with no
  /// current role still qualifies, so it can be given one.
  bool _canChangeRole(AssignmentEntry entry) =>
      widget.roles.isNotEmpty &&
      widget.onRoleChanged != null &&
      widget.enabled &&
      !widget.lockedIds.contains(entry.id);

  Widget _chip(AssignmentEntry entry) {
    final locked = widget.lockedIds.contains(entry.id);
    Widget build([VoidCallback? onRolePressed]) => widget.chipBuilder(
      entry.id,
      locked: locked,
      onDeleted: (locked || !widget.enabled) ? null : () => _remove(entry.id),
      roleLabel: entry.roleLabel,
      onRolePressed: onRolePressed,
    );

    final onRoleChanged = widget.onRoleChanged;
    if (onRoleChanged == null || !_canChangeRole(entry)) return build();
    return RoleMenu(
      roles: widget.roles,
      currentRoleId: widget.rolesById[entry.id],
      onSelected: (roleId) => onRoleChanged(entry.id, roleId),
      builder: build,
    );
  }

  Widget _editButton(BuildContext context) => IconButton(
    icon: Icon(widget.editIcon),
    tooltip: widget.editLabel,
    onPressed: () => _openPicker(context),
  );

  /// Transitions the field between sizes as chips come and go, so adding or
  /// removing one — or expanding the overflow — reads as a deliberate response
  /// to the edit rather than a one-frame snap of the surrounding layout. Every
  /// size change the field owns is inside: the chip flow itself, the
  /// empty-hint swap, and the expanded overflow row.
  ///
  /// Skipped entirely when the platform asks for reduced motion, so a user who
  /// has turned system animations off doesn't get one the caller never opted
  /// into — same result as passing [AssignmentField.sizeAnimationDuration] of
  /// [Duration.zero].
  Widget _animateSize(BuildContext context, Widget child) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : widget.sizeAnimationDuration;
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      alignment: AlignmentDirectional.topStart,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultRoleId = widget.defaultRoleId;
    assert(
      widget.roles.isEmpty ||
          defaultRoleId == null ||
          widget.roles.any((role) => role.id == defaultRoleId),
      'defaultRoleId must be the id of one of roles',
    );
    return widget.singleLine
        ? _buildSingleLine(context)
        : _buildStacked(context);
  }

  Widget _buildStacked(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEntries = _selectedEntries;
    final cap = widget.maxVisibleChips;
    final collapsed = cap != null && !_expanded && selectedEntries.length > cap;
    final visibleEntries = collapsed
        ? selectedEntries.take(cap).toList()
        : selectedEntries;
    final hiddenCount = selectedEntries.length - visibleEntries.length;

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
        _animateSize(
          context,
          selectedEntries.isEmpty
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
                    for (final entry in visibleEntries) _chip(entry),
                    if (hiddenCount > 0)
                      ActionChip(
                        label: Text('+$hiddenCount more'),
                        onPressed: () => setState(() => _expanded = true),
                      ),
                    if (_expanded &&
                        cap != null &&
                        selectedEntries.length > cap)
                      ActionChip(
                        label: const Text('Show less'),
                        onPressed: () => setState(() => _expanded = false),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSingleLine(BuildContext context) {
    final theme = Theme.of(context);
    final selectedEntries = _selectedEntries;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for at least one chip (plus an overflow chip, if there
        // would be one) before sizing the label, so a long name can never
        // squeeze every chip out of the row — it ellipsizes instead.
        const editButtonWidth = 48.0;
        const labelGap = 12.0;
        final editWidth = widget.enabled ? editButtonWidth : 0.0;
        final minChipsWidth = _minChipsWidth(context, selectedEntries);
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
            : _textWidth(context, widget.label!).clamp(0.0, labelMaxWidth);
        final chipAreaWidth =
            (constraints.maxWidth - editWidth - labelWidth - labelGapWidth)
                .clamp(0.0, double.infinity);

        var fitted = _fitChips(context, selectedEntries, chipAreaWidth);
        final cap = widget.maxVisibleChips;
        if (cap != null && fitted.visible.length > cap) {
          fitted = (
            visible: fitted.visible.take(cap).toList(),
            hiddenCount: fitted.hiddenCount + (fitted.visible.length - cap),
          );
        }
        final hiddenEntries = selectedEntries
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
              child: selectedEntries.isEmpty
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
                        for (final entry in fitted.visible) _chip(entry),
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

        // The animation wraps the built result rather than the LayoutBuilder,
        // so the chip-fitting math above still sees the field's real width.
        if (!_expanded || hiddenEntries.isEmpty) {
          return _animateSize(context, row);
        }

        // Expanded: leave the row above exactly as it was and append a second
        // row with the entries that didn't fit, wrapping onto as many lines as
        // needed, plus a "Show less" affordance to collapse back.
        return _animateSize(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row,
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final entry in hiddenEntries) _chip(entry),
                  ActionChip(
                    label: const Text('Show less'),
                    onPressed: () => setState(() => _expanded = false),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// The narrowest the chip area can be while still showing the "+N more"
  /// overflow chip on its own — worst case, every entry is hidden behind it.
  /// [_buildSingleLine] caps the label to whatever width is left over after
  /// this, so an overlong label ellipsizes instead of squeezing the row down
  /// to nothing at all. It's fine for a long label to push every real chip
  /// out in favor of just the overflow chip — see [_fitChips].
  double _minChipsWidth(BuildContext context, List<AssignmentEntry> entries) {
    if (entries.isEmpty) return 0;
    return _estimateOverflowChipWidth(context, entries.length);
  }

  /// Estimates how many leading [entries] fit within [maxWidth] on a single
  /// line, reserving room for a trailing "+N more" chip when not all of them
  /// do. Chip widths are estimated from label text metrics rather than a real
  /// layout pass — close enough to size the row without the cost (and
  /// complexity) of rendering twice; being off by a chip's width in either
  /// direction is an acceptable trade-off for a density heuristic.
  ({List<AssignmentEntry> visible, int hiddenCount}) _fitChips(
    BuildContext context,
    List<AssignmentEntry> entries,
    double maxWidth,
  ) {
    const spacing = 8.0;
    final widths = [
      for (final entry in entries)
        _estimateChipWidth(
          context,
          entry,
          removable: widget.enabled && !widget.lockedIds.contains(entry.id),
          canChangeRole: _canChangeRole(entry),
        ),
    ];

    var total = 0.0;
    for (var i = 0; i < widths.length; i++) {
      total += widths[i] + (i == 0 ? 0 : spacing);
    }
    if (total <= maxWidth) return (visible: entries, hiddenCount: 0);

    var used = 0.0;
    var count = 0;
    for (var i = 0; i < entries.length; i++) {
      final next = used + (count == 0 ? 0 : spacing) + widths[i];
      final overflowWidth = _estimateOverflowChipWidth(
        context,
        entries.length - (count + 1),
      );
      if (next + spacing + overflowWidth > maxWidth) break;
      used = next;
      count++;
    }
    // Zero is a legitimate outcome here — an extremely narrow row (or a long
    // label crowding the chip area, see _minChipsWidth) shows just the
    // overflow chip rather than clipping a real one.
    count = count.clamp(0, entries.length);
    return (
      visible: entries.take(count).toList(),
      hiddenCount: entries.length - count,
    );
  }

  double _estimateChipWidth(
    BuildContext context,
    AssignmentEntry entry, {
    required bool removable,
    required bool canChangeRole,
  }) {
    // M3 chip chrome this approximates: a 24dp avatar plus its gap to the
    // label, ~12dp label padding on each side, and — when removable — a
    // trailing delete icon plus its gap. A role adds its " · role" text and,
    // when it can change, a trailing drop-down glyph.
    const avatarAndGap = 32.0;
    const labelPadding = 24.0;
    const deleteAffordance = 26.0;
    const roleChevron = 22.0;
    final roleLabel = entry.roleLabel;
    final text = roleLabel == null
        ? entry.label
        : '${entry.label} · $roleLabel';
    return avatarAndGap +
        labelPadding +
        _textWidth(context, text) +
        (removable ? deleteAffordance : 0) +
        (canChangeRole ? roleChevron : 0);
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
