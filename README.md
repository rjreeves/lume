# Compress, hash, copy, and log first-level folders

`compress_first_level.lume` creates one ZIP archive for every immediate child
directory under a root directory. It calculates a SHA-256 hash, copies each ZIP
to one or more destination folders, verifies every copy, and logs the result in
a SQLite database. Nested directories remain inside their parent's ZIP.

Run it with the local Lume executable:

```powershell
C:\Users\robert\Desktop\Lume\dist\lume.exe run .\compress_first_level.lume `
  "C:\path\to\root" `
  "D:\backup"
```

Multiple destinations and a custom database path are supported:

```powershell
C:\Users\robert\Desktop\Lume\dist\lume.exe run .\compress_first_level.lume `
  "C:\path\to\root" `
  "D:\backup" `
  "E:\second-copy" `
  --db "D:\logs\archive_log.sqlite3"
```

If `--db` is omitted, `archive_log.sqlite3` is created in the first destination.
The `archive_log` table stores the run ID, source and archive paths, SHA-256,
size, UTC timestamp, status, and any error. Existing ZIPs are replaced only
after a new ZIP has been created successfully.

Requirements: Windows PowerShell and `python.exe` with Python's standard
`sqlite3` module.

## Detect changed files with BLAKE3

The standalone Rust executable is `target\release\b3changes.exe`. It requires
no Python installation or other runtime dependencies. To rebuild it:

```powershell
cargo build --release
```

Create the initial recursive baseline for a root folder:

```powershell
.\target\release\b3changes.exe "D:\path\to\root"
```

Run the same command later to report `ADDED`, `MODIFIED`, and `DELETED`
files. The baseline is stored in `<root>\.blake3-manifest.json`. A comparison
returns exit code 0 when nothing changed and 1 when changes are found. To accept
the current tree as the new baseline after reporting changes, add `--update`:

```powershell
.\target\release\b3changes.exe "D:\path\to\root" --update
```

Use `--manifest "D:\somewhere\baseline.json"` to keep the manifest outside
the scanned tree. Unreadable files are reported as errors and produce exit code
2; the scanner never treats them as successfully hashed. Exit code 0 means no
changes, 1 means changes were found, and 64 means the command or manifest was
invalid.
