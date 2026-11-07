# What's new, per version

`<version>.json` holds a few short lines per language (`it`, `en`) that the app shows in the update dialog
before downloading (`lib/update/update_ui.dart`). Keep them short and plain: they are not the changelog.

The release workflow copies the file of the latest published version into `version.json` as `notes`, and puts the
English lines at the top of the GitHub Release notes. A version without a file simply has no notes.
