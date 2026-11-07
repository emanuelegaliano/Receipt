# Changelog

What changes in Receipt, one section per published version.

## 0.3.5

### New
- Your expenses and receipt photos are now encrypted on the phone. Someone who copies the app's files (for example
  from a rooted phone) sees only unreadable data; it opens only with your password or your fingerprint.
  - The database is encrypted with SQLite3MultipleCiphers, each photo with AES-256-GCM, using a random key. That key
    is kept in the Android Keystore, locked by your password; the password itself is not stored anywhere.
  - The fingerprint opens the same key through a Keystore key that Android unlocks only after a recognised
    fingerprint. If you add or remove a fingerprint on the phone, Receipt asks for the password once and offers to
    turn the fingerprint on again.
- The update dialog shows a few lines on what's new before downloading (from the next update on: 0.3.4 cannot show
  them).

### Changed
- After updating, the first unlock must be with the password, not the fingerprint: it is needed to encrypt the data
  you already have. If the fingerprint was on, Receipt then asks you to confirm it once.
- Export data asks for the password (not the fingerprint) before creating the zip. The zip itself is still not
  encrypted, so it can be opened anywhere and restored on another phone; photos in it are plain JPEGs.
- Android's automatic backup is off for Receipt: the encrypted data could not be opened on another phone anyway. Use
  Export data.

### Fixed
- Plain copies of photos and backups no longer stay in the app's cache: the copies made by the photo picker, the
  share sheet and the file picker, and earlier exports, are deleted.

## 0.3.4

### Fixed
- Turning the painting of the day off and on again no longer downloads it again: the image stays on the phone while
  the painting is off, and the same day it comes back straight away. On another day the old painting is shown until
  the new one has arrived, then the old image is removed.

## 0.3.3

### Fixed
- A backup that had been unzipped and zipped again (for example after WhatsApp or Telegram, or on a computer) was
  refused with "This zip is not a Receipt backup" because its files were inside a folder. Receipt now looks inside
  the folder, and ignores the extra files added by macOS (`__MACOSX`, `.DS_Store`) and Windows-style paths.
- When a zip is refused, the message now names the file, what is missing and what the zip contains.
- Restoring a backup made before 0.3.2 no longer turns the painting of the day off for good: Receipt asks again at
  the next launch.

## 0.3.2

### New
- Painting of the day, if you want it: a public-domain painting from The Metropolitan Museum of Art as the background
  of Summary, Transactions and Categories, a different one every day out of 600 vertical works. Receipt asks at first
  launch (and once after updating); you can change it in Settings → Appearance.
  - One image a day (about 0.7 MB) is downloaded from Wikimedia Commons; none of your data is sent. If the internet is
    not available, yesterday's painting stays.
  - The "i" at the top opens the painting: the whole image (tap to zoom), author, date, medium, dimensions, the
    introduction of its Wikipedia article where there is one, and links to The Met, Wikipedia and Commons.
  - A slider sets how visible the painting is (5–50%, 20% by default), with a preview.
  - The password and fingerprint screen stays plain.

### Changed
- The internet is now used for the update check and for the painting of the day, each only if you allow it.

## 0.3.1

### New
- Automatic updates, if you want them: at first launch Receipt asks whether it may check online for new versions.
  When one is out, a banner tells you; the app downloads it, checks its SHA-256 and opens the Android installer.
  You can change your mind in Settings → Updates.
- Jump to any month: tap the month name in Transactions or Summary to pick month and year.
- 36 more icons for categories.

### Fixed
- The app could close by itself after scanning many receipts in a row: it now uses about a third of the memory
  (ONNX Runtime without the CPU arena, smaller previews, image cache capped at 32 MB).
- If Android closes Receipt while the camera is open, the photo is no longer lost: it is read when the app restarts.

### Changed
- The app now has the INTERNET and REQUEST_INSTALL_PACKAGES permissions, used only for the optional update check
  and to install updates. No data is collected.

## 0.1.0

First release: receipts read on the phone, card and cash expenses, categories that learn, monthly limits, lock with
password and fingerprint, backup to a .zip, English and Italian.
