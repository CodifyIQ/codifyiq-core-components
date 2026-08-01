import 'package:flutter/material.dart';

import 'group.dart';
import 'group_color.dart';
import 'unsaved_changes_guard.dart';

/// A Material 3 dialog for creating or editing a [Group].
///
/// Collects a required name, an optional description, an optional theme-derived
/// accent ([GroupColor]) and an optional icon chosen from a small preset
/// palette. The dialog performs no persistence — it returns the assembled
/// [Group] to the caller, which is responsible for adding or updating it (e.g.
/// via a [GroupManagerController]).
///
/// Use [show] to present it; the future completes with the saved [Group], or
/// `null` if the user cancels.
class GroupEditorDialog extends StatefulWidget {
  /// Creates a [GroupEditorDialog].
  ///
  /// When [initial] is supplied the dialog opens in edit mode, pre-filled with
  /// that group's values and preserving its id on save. When omitted, a new id
  /// is generated from the current time on save.
  const GroupEditorDialog({super.key, this.initial});

  /// The group being edited, or `null` when creating a new group.
  final Group? initial;

  /// Preset icons offered in the editor.
  static const List<IconData> iconPresets = <IconData>[
    Icons.group,
    Icons.admin_panel_settings,
    Icons.shield,
    Icons.engineering,
    Icons.support_agent,
    Icons.school,
    Icons.account_balance,
    Icons.science,
  ];

  /// Shows the dialog and resolves with the saved [Group], or `null` if the
  /// user cancels.
  static Future<Group?> show(BuildContext context, {Group? initial}) {
    return showDialog<Group>(
      context: context,
      builder: (_) => GroupEditorDialog(initial: initial),
    );
  }

  @override
  State<GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<GroupEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  GroupColor? _color;
  IconData? _icon;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _description = TextEditingController(
      text: widget.initial?.description ?? '',
    );
    _color = widget.initial?.color;
    _icon = widget.initial?.icon;
    _name.addListener(_syncDirty);
    _description.addListener(_syncDirty);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Whether the form differs from the group it opened with — the signal that
  /// dismissing the dialog would throw work away.
  bool get _isDirty =>
      _name.text.trim() != (widget.initial?.name ?? '') ||
      _description.text.trim() != (widget.initial?.description ?? '') ||
      _color != widget.initial?.color ||
      _icon != widget.initial?.icon;

  // Typing rebuilds the fields on its own; rebuild the dialog only when the
  // dirty flag actually flips, so the guard stays in sync without a setState
  // per keystroke.
  void _syncDirty() {
    if (_isDirty != _dirty) setState(() => _dirty = _isDirty);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final description = _description.text.trim();
    final result = Group(
      id:
          widget.initial?.id ??
          'group-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      description: description.isEmpty ? null : description,
      color: _color,
      icon: _icon,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return UnsavedChangesGuard(
      hasChanges: _isDirty,
      child: AlertDialog(
        // Scroll the content so a short viewport (or the validation message
        // expanding the form) never overflows.
        scrollable: true,
        title: Text(isEditing ? 'Edit group' : 'New group'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Administrators',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _SectionLabel('Color'),
                const SizedBox(height: 8),
                _ColorPalette(
                  selected: _color,
                  onSelected: (c) => setState(() => _color = c),
                ),
                const SizedBox(height: 20),
                _SectionLabel('Icon'),
                const SizedBox(height: 8),
                _IconPalette(
                  selected: _icon,
                  onSelected: (i) => setState(() => _icon = i),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            // maybePop, not pop, so Cancel goes through the discard prompt too.
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _save,
            child: Text(isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({required this.selected, required this.onSelected});

  final GroupColor? selected;
  final ValueChanged<GroupColor?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // "Auto" — derive a stable role from the group id.
        InkResponse(
          radius: 24,
          onTap: () => onSelected(null),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(
              selected == null ? Icons.check : Icons.auto_awesome,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final role in GroupColor.values)
          _Swatch(
            role: role,
            selected: selected == role,
            onTap: () => onSelected(role),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final GroupColor role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (:background, :foreground) = role.resolve(
      Theme.of(context).colorScheme,
    );
    return InkResponse(
      radius: 24,
      onTap: onTap,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: background,
        child: selected ? Icon(Icons.check, size: 16, color: foreground) : null,
      ),
    );
  }
}

class _IconPalette extends StatelessWidget {
  const _IconPalette({required this.selected, required this.onSelected});

  final IconData? selected;
  final ValueChanged<IconData?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final icon in GroupEditorDialog.iconPresets)
          IconButton.filledTonal(
            isSelected: selected == icon,
            onPressed: () => onSelected(selected == icon ? null : icon),
            icon: Icon(icon),
            style: selected == icon
                ? IconButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  )
                : null,
          ),
      ],
    );
  }
}
