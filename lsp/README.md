# Lume language server

This is the lighter of two LSP options. For most editors, prefer the
compiler's own built-in server instead — `dist\lume.exe lsp` — which adds
go-to-definition/hover/references/rename with one level of cross-file
`use`-import resolution, document and workspace symbols, and quickfix code
actions; see the main [README.md](../README.md#editor-support) for details.
Reach for this script when you specifically want its independent formatter,
or don't want to depend on the compiler binary's own LSP subcommand.

`lume-lsp.ps1` is a standard LSP 3.x server over stdio. It uses the Certo-built
Lume compiler for live static diagnostics and provides:

- full-document synchronization and diagnostics;
- keyword and core-API completion;
- hover information;
- same-document function definitions;
- canonical document formatting.

Start it from an editor LSP client with:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lsp\lume-lsp.ps1
```

The server expects `dist\lume.exe`; run `build.ps1` first. An alternative compiler
path can be supplied with `-Lume C:\path\to\lume.exe`.

Run `lsp\test.ps1` for an end-to-end protocol smoke test.
