# Music Hub backup format 1

Backup is a complete snapshot of the active saved library; Export is an individual readable document/audio file. Both use the native Files interface. Backups do not contain a SQLite database.

```text
MusicHub Backup/
  library.json
  songs/<song-uuid>/
    chords.txt
    tab.txt          (when a tab exists)
    notes.txt        (when notes exist)
    annotations.txt
  recordings/<asset-uuid>.<original-extension>
```

All text is UTF-8. Tabs are the stored ASCII continuation text; annotations remain separate so restoration preserves them exactly. Multiple recordings sharing the same asset include that audio once. ZIP audio entries are stored without recompressing them. ZIP creation/extraction runs in an isolate and streams file contents; audio is not accumulated as one giant byte buffer.

`library.json` contains `application: "MusicHub"`, `formatVersion: 1`, snapshot `createdAt`, `ownerId`, preferences, Songs, recordings, and a `files` map with each payload's SHA-256 and byte size. Song metadata includes stable Song/arrangement/document IDs, title/artist, createdAt/lastEdited, logical `editOrder`, tuning/capo/tempo, notes title and document file references. Recording metadata includes stable Recording/asset IDs, title, capture/import date, duration, SHA-256, audio path and optional Song ID. Link-row IDs are implementation details and regenerated; the associations themselves are preserved.

Preferences include Dark Mode, metronome and tuner tuning. Device identity is local to the installation. Restore advances the local logical counter beyond restored edit orders, so subsequent edits sort correctly without relying on the wall clock. Database revision numbers are not a portable schema contract. Song creation dates begin with database version 5; missing historical creation/edit dates are represented as empty strings, never guessed.

## Restore semantics

1. Pick a ZIP, copy into private staging, and validate before touching the library. Unknown versions, unsafe/duplicate paths, symlinks, unexpected/missing files, malformed IDs/dates/preferences, invalid relationships and checksum/size mismatches are rejected.
2. Show the backup date and Song/recording counts; ask to **replace** the library. Cancel removes staging and leaves the library unchanged. Restore does not merge. Save a separate backup first if the current library should be kept.
3. Copy verified audio to a unique private installation directory; verify again at the commit boundary. Then restore all metadata in **one SQLite transaction**. Old metadata is tombstoned; stable imported IDs are reused. A database failure rolls back and removes newly installed audio.
4. Clean up staging. Existing audio files are not overwritten or deleted. A crash before metadata commit can leave unreferenced files, but does not point the library at half-installed audio. Cleanup failure does not negate a completed restore.

Unfinished recording drafts block backup and restore until saved/discarded. Deleted objects and unreferenced blobs are excluded from the active-library backup. Saved-document history is neither stored nor restored. Available disk space must accommodate the archive, staging and installed audio; low-storage failures occur before metadata replacement. ZIPs are not encrypted; choose the destination appropriate for your own content.

## V1 bounds and interoperability

- Up to 10,000 Songs, 20,000 recordings and 60,001 archive entries.
- Maximum 8 MiB per text field, 64 MiB aggregate document/metadata text, 16 MiB manifest, 2 GiB per audio payload, 8 GiB total expanded archive. Oversized input fails explicitly. These are defensive limits, not claims of device performance at those sizes.
- Existing built-in m4a recordings and imported m4a/mp3/wav/aac/aif/aiff/caf/flac/ogg files retain their original bytes. Import additionally requires native playback to recognize a positive duration; codecs vary by device.
- Direct plain-text import is exact except an optional UTF-8 BOM. Simple ChordPro import recognizes title/t/artist, soc/start_of_chorus, eoc/end_of_chorus and common bracket chords; unknown text/directives remain literal. Export uses plain text, not a claim of full ChordPro equivalence.

Native dialogs use Flutter's [file_selector](https://pub.dev/packages/file_selector) for picking and [file_saver saveAs](https://pub.dev/documentation/file_saver/latest/file_saver/FileSaver/saveAs.html) with a file path for saving. The [archive package](https://pub.dev/packages/archive) supplies streaming ZIP I/O. No backend or network service is involved; an iCloud Files destination may itself require connectivity.
