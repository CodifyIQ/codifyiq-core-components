## 1.0.0

* Initial release as a standalone package, extracted from `codifyiq_core_components`.
* `UserAvatar` — a circular avatar with photo, initials, and icon fallbacks.
* `imageProvider` parameter — supply a ready-made `ImageProvider` (e.g. `MemoryImage`, `FileImage`, `AssetImage`) for the avatar photo from a non-URL source; it renders through the same circular-clip, cover-fit, and error-to-initials fallback as a network photo.
* Parenthetical qualifiers in a display name (e.g. `"Java Joe (Contractor)"`, common in enterprise and government directories) are stripped before deriving initials, so the avatar shows `"JJ"` instead of `"J("`. This applies to both `UserAvatar` and the public `UserAvatar.initialsFor` helper.
