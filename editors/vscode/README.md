# Lume for VS Code

A small VS Code extension with two jobs, both thin wrappers around the
compiler binary:

- **Language features** from the compiler's own language server (`lume lsp`):
  diagnostics, hover, go to definition, find references, rename, completion,
  quick fixes (insert `fn main`, add a missing `use`, "did you mean"), document
  outline, and workspace symbol search. See the main README's
  [Editor support](../../README.md#editor-support) for exactly what the server
  does and its limits (notably, one diagnostic per file).
- **Debugging** `.lume` files through the compiler's Debug Adapter Protocol
  server (`lume debug <file> --dap`).

It has no npm dependencies and no build step: the language client is a small
hand-written LSP transport (`lspClient.js`), not `vscode-languageclient`.

## Install

1. Build the compiler: `pwsh build.ps1` (produces `dist\lume.exe`).
2. Package and install the extension (no node or vsce needed):

   ```powershell
   pwsh editors\vscode\package.ps1
   code --install-extension dist\lume-debug-<version>.vsix
   ```

3. Open the Lume repository (or any folder with a `dist\lume.exe`) in VS Code,
   or set `lume.path` to your `lume.exe`. Opening a `.lume` file starts the
   language server; output and errors go to the **Lume Language Server**
   output channel. If `lume.exe` can't be found, that channel lists every
   location that was tried and how to fix it (and a one-time popup offers
   "Show Details").

To hack on the extension instead, open `editors/vscode` in VS Code and press F5
(Extension Development Host), or run
`code --extensionDevelopmentPath=<path to editors/vscode> <folder>`.

## Settings and commands

| Name | Meaning |
| --- | --- |
| `lume.path` | Path to `lume.exe`. When empty, `dist\lume.exe` in the first workspace folder is used. |
| `lume.lsp.enable` | Start the language server (default true). |
| `Lume: Restart Language Server` | Restart `lume lsp`, e.g. after rebuilding `lume.exe`. |

## Debugging

In a `.lume` file, set a breakpoint and choose Run > Start Debugging. VS Code
offers a "Debug Lume file" launch configuration (type `lume`,
`program: ${file}`) when it creates `.vscode/launch.json`.

| Launch option | Meaning |
| --- | --- |
| `program` | The `.lume` file to debug (usually `${file}`). Required. |
| `stopOnEntry` | Stop before the first line of `main`. Default false. |
| `lumePath` | `lume.exe` for this configuration. |

Limits inherited from the adapter, see `docs/debugger-scoping.md`: line
breakpoints only, locals only, no conditional breakpoints, and breakpoints match
by line across the whole combined source.

## Tests

`test/extension.test.js` loads the real `extension.js` against a stand-in for
the `vscode` module and drives it against a real `lume.exe lsp` (diagnostics,
hover, definition, references, rename, completion, code actions, symbols, and
live edits). It needs only Node; VS Code's bundled one works:

```powershell
$env:ELECTRON_RUN_AS_NODE = '1'
& "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe" editors\vscode\test\extension.test.js
```

Pass a `lume.exe` path as the argument, or set `LUME`, to test a build other
than `dist\lume.exe`.

## Notes

The language server compares document URIs as plain strings and converts them
to paths without percent-decoding, so the extension sends unencoded `file:///c:/...`
URIs rather than VS Code's default `file:///c%3A/...`; with the default form,
`use` imports of files that aren't open in the editor would not resolve.
