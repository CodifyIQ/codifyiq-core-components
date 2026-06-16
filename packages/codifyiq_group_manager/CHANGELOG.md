## 1.0.0

* Initial release.
* `GroupManagerController` + `GroupManagerScope` — a UI-only state container for a flat catalog of authorization groups and their assignment to principals (no nested groups, no separate roles).
* `GroupManagerView` and `GroupListView` — drop-in Material 3 surfaces for creating, editing, and deleting groups, with cascade-unassign on delete and built-in search to filter long catalogs. `GroupManagerView` caps its content to a comfortable measure and centers it on large screens (configurable via `maxContentWidth`). Intercept persistence with `onCreate` / `onEdit` / `onDelete` to wire create/edit/delete to a backend before (or instead of) mutating the controller.
* `GroupColor` — group accents are theme-derived roles (`primary`/`secondary`/`tertiary`/`neutral`) resolved against the active `ColorScheme`, so they adapt to light/dark; a stable role is auto-assigned when none is set.
* `GroupAssignmentField` — assign one or more groups to a target via removable chips and a stationary edit button that opens a searchable picker (which both adds and removes membership). Customize the trigger's tooltip and glyph via `editLabel` / `editIcon` — e.g. an authorization icon when granting access rather than editing membership.
* `GroupPicker` — a searchable, multi-select group picker that adapts between a bottom sheet (compact widths) and a dialog (large screens).
* `GroupEditorDialog`, `GroupChip`, and `GroupAvatar` — composable building blocks for custom group-management screens.
