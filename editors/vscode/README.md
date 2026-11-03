# Lume Debugger for VS Code

A minimal extension that lets VS Code debug a `.lume` file using the compiler's
own Debug Adapter Protocol server (`lume debug <file> --dap`). It has no
dependencies and no build step.

## Try it

1. Build the compiler: `pwsh build.ps1` (produces `dist\lume.exe`).
2. Open the repository folder in VS Code, then open
   `editors/vscode` in a second window and press F5 (Extension Development
   Host), or run `code --extensionDevelopmentPath=<path to editors/vscode> <folder>`.
3. In the new window open a `.lume` file, set a breakpoint, and choose
   Run > Start Debugging. VS Code offers a "Debug Lume file" launch
   configuration (type `lume`, `program: ${file}`) when it creates
   `.vscode/launch.json`.

## Launch options

| Option | Meaning |
| --- | --- |
| `program` | The `.lume` file to debug (usually `${file}`). Required. |
| `stopOnEntry` | Stop before the first line of `main`. Default false. |
| `lumePath` | `lume.exe` for this configuration. |

`lume.path` in settings sets it globally; if neither is set, `dist\lume.exe` in
the first workspace folder is used.

## Limits

Inherited from the adapter, see `docs/debugger-scoping.md`: line breakpoints
only, locals only, no conditional breakpoints, and breakpoints match by line
across the whole combined source. Tried by hand in VS Code: a breakpoint stops
with locals shown, and Continue runs the program to the end.
