## 1.3.0

* Membership can now be managed from **either end** of the relation. Everything that assigns groups to a member has a mirror that adds members to a group; both read and write the same assignments, so an edit made from one side is immediately visible from the other.
* `Principal` — an immutable member model (id, name, optional description/photo/icon), plus `PrincipalAvatar` and `PrincipalChip`. The roster stays caller-owned: map your own user type onto `Principal` at the widget boundary, exactly as you already supply the `Group` catalog. `copyWith` produces modified copies. Avatars are rendered by `UserAvatar` from `codifyiq_user_avatar`, so a member looks the same here as on every other screen in your app — including its initials, which skip bracketed qualifiers common in enterprise directories (`"Alice [Contractor]"` reads as `"AL"`, not `"A["`).
* Member photos load the same way as everywhere else in your app. `PrincipalAvatar` takes `headers` and `imageProviderBuilder` — matching `UserAvatar` in `codifyiq_user_avatar` — so a photo behind an authenticated endpoint loads instead of silently falling back to initials, and a photo already in your app's cache is served from it rather than refetched. `GroupMembersView`, `MemberPicker`, and `MemberAssignmentField` expose the pair as `avatarHeaders` / `avatarImageProviderBuilder` and pass it to every member avatar they render, including the ones inside their pickers; `PrincipalChip` takes it as `headers` / `imageProviderBuilder`. Pass a stable builder reference — a closure allocated inside `build` re-fetches the photo every frame. For a photo that isn't a fetchable URL at all — base64 bytes from your directory, a cached file, a bundled asset — hand `Principal` an `imageProvider` instead of an `imageUrl`; it takes precedence and renders through the same circular clip and initials/icon fallback.
* `GroupMembersView` — a drop-in surface for one group's membership, with search, an "Edit members" picker, per-row and bulk removal (both confirmed), and `onMembersAdded` / `onMembersRemoved` hooks for persisting to a backend. Pass it as the destination of `GroupManagerView.onTap` to drill from the catalog into a group's members. Use `lockedMemberIds` for memberships that can't be removed — e.g. a group's owner — mirroring `lockedIds` elsewhere.
* `MemberAssignmentField` — the counterpart of `GroupAssignmentField` for a single group inline on a form, with the same chips, `lockedIds`, `maxVisibleChips`, and `singleLine` options.
* `MemberPicker` — the counterpart of `GroupPicker`: a searchable, multi-select member picker that adapts between a bottom sheet (compact widths) and a dialog (large screens).
* Unsaved work is no longer lost to an accidental dismissal. Once the group editor has been typed in, or a picker's selection has been changed, clicking off the surface, pressing Escape, or the system back gesture asks "Discard changes?" first; Cancel goes through the same prompt. An untouched editor or picker still closes immediately. This applies to `GroupEditorDialog`, `GroupPicker`, `MemberPicker`, and `GroupBulkAssignmentDialog`.
* On compact widths the pickers' bottom sheet no longer closes on a downward swipe — swipe-to-dismiss bypasses the confirmation above, so dismissal is via the barrier, back gesture, or Cancel.
* `GroupManagerController.membersOf` / `memberCount` / `setMembers` — read and rewrite a group's membership directly. `setMembers` rewrites only that group's column, so a principal removed from one group keeps every other group they belong to.

## 1.2.0

* `GroupManagerController.assignMany` / `unassignMany` — add or remove groups across many principals in one call.
* `GroupBulkAssignmentDialog` — a picker for choosing groups to bulk-assign (`show`) or bulk-remove (`showRemoval`) across many principals; `showRemoval` accepts `lockedIds` to keep protected groups off the offered list.
* `maxVisibleChips` on `GroupAssignmentField` — cap visible chips, collapsing the rest behind "+N more".
* `singleLine` on `GroupAssignmentField` — a denser layout with the label, chips, and edit button on one row.
* `destructive` on `GroupPicker` — tints checkboxes and the confirm button with the error color, for pickers where checking a box means removing rather than keeping.
* `BulkSelectionBar` — a fixed-height selection toolbar (select all/none + bulk actions) for any list, with no dependency on `Group`.
* Fixed: `GroupPicker`'s action row could overflow with a long `confirmLabel`; it now wraps instead.

## 1.1.0

* `lockedIds` on `GroupAssignmentField`, `GroupPicker`, `GroupManagerView`, and `GroupListView` — designate permanent groups (e.g. an "Admin" group that always has access). When assigning, locked groups always show as chips bearing a lock glyph in place of the remove affordance (tooltip: "Required — can't be removed"), appear checked-and-disabled with the same lock glyph in the picker, and are always present in the resulting selection regardless of user interaction. In the catalog, a locked group's row shows a lock badge (tooltip: "Locked — can't be deleted") and offers no Delete action (it stays editable), so the permanent group your assignments depend on can't be deleted out from under them.
* `footer` on `GroupManagerView` and `GroupListView` — render a help or policy note beneath the last group that scrolls with the catalog.

## 1.0.0

* Initial release.
* `GroupManagerController` + `GroupManagerScope` — a UI-only state container for a flat catalog of authorization groups and their assignment to principals (no nested groups, no separate roles).
* `GroupManagerView` and `GroupListView` — drop-in Material 3 surfaces for creating, editing, and deleting groups, with cascade-unassign on delete and built-in search to filter long catalogs. `GroupManagerView` caps its content to a comfortable measure and centers it on large screens (configurable via `maxContentWidth`). Intercept persistence with `onCreate` / `onEdit` / `onDelete` to wire create/edit/delete to a backend before (or instead of) mutating the controller.
* `GroupColor` — group accents are theme-derived roles (`primary`/`secondary`/`tertiary`/`neutral`) resolved against the active `ColorScheme`, so they adapt to light/dark; a stable role is auto-assigned when none is set.
* `GroupAssignmentField` — assign one or more groups to a target via removable chips and a stationary edit button that opens a searchable picker (which both adds and removes membership). Customize the trigger's tooltip and glyph via `editLabel` / `editIcon` — e.g. an authorization icon when granting access rather than editing membership.
* `GroupPicker` — a searchable, multi-select group picker that adapts between a bottom sheet (compact widths) and a dialog (large screens).
* `GroupEditorDialog`, `GroupChip`, and `GroupAvatar` — composable building blocks for custom group-management screens.
