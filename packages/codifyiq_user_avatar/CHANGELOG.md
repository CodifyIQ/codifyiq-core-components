## 1.2.0

* `photoBytes` and `photoBase64` parameters — render an avatar photo you already hold in memory, or one that arrived base64-encoded from an OAuth provider or JSON API, without building an `ImageProvider` yourself. `photoBase64` also accepts a `data:` URI, and an undecodable string falls back to initials rather than throwing.
* Avatar photos no longer flicker or re-decode when a list rebuilds. The widget owns the `MemoryImage` behind `photoBytes` / `photoBase64` and reuses it while the bytes are unchanged, so you can build them inline in `build()` — no more per-item provider cache keyed on user id. An `imageProvider` you pass is likewise compared by value, including the bytes of a `MemoryImage` — on its own or wrapped in a `ResizeImage`.

## 1.1.1

* Square- and curly-bracketed qualifiers in a display name (e.g. `"Alice [Contractor]"`, `"Alice {External}"`) are now stripped before deriving initials, alongside the parenthetical form already handled. `"Alice [Contractor]"` shows `"AL"` instead of `"A["`.

## 1.1.0

* `SelectableAvatarLeading` — a list row's leading control that swaps a `UserAvatar` for a tappable check icon on hover, or permanently once selected: the Google Contacts pattern for starting a multi-select without dedicating a whole column to checkboxes up front.

## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `UserAvatar` — a circular avatar with photo, initials, and icon fallbacks.
* `imageProvider` parameter — supply a ready-made `ImageProvider` (e.g. `MemoryImage`, `FileImage`, `AssetImage`) for the avatar photo from a non-URL source; it renders through the same circular-clip, cover-fit, and error-to-initials fallback as a network photo.
* Parenthetical qualifiers in a display name (e.g. `"Java Joe (Contractor)"`, common in enterprise and government directories) are stripped before deriving initials, so the avatar shows `"JJ"` instead of `"J("`. This applies to both `UserAvatar` and the public `UserAvatar.initialsFor` helper.
