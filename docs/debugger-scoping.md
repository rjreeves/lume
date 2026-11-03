# Debugger protocol: scoping

Status: milestone 1 implemented (see "Milestone 1 result" at the end); the rest is
proposal. It covers the ROADMAP item
"debugger protocol support after bytecode/source maps stabilize".

## Is the precondition met?

The roadmap gates this on "bytecode/source maps". Reading SPEC.md section 17
and `src/lume.cto`:

- There is no separate source map. Every `Instruction` is
  `{op, text, number, line}`, so each instruction already carries its source
  line. That is enough for line breakpoints and stepping.
- There is no column on instructions (tokens have columns, instructions do
  not). Column-level stepping is out of scope for v1.
- Bytecode format is versioned (`LBC5` header, `lume bytecode` lister), so the
  gate is effectively met for line-level debugging.

## What a debugger needs from the VM today

`execute(code)` (`src/lume.cto`, around line 5726) is one big loop over `ip`
with local state: `stack`, `variables` (bindings keyed `depth:name` via
`scopedName`), `returnAddresses`, `matchVariable*`, `depth`. There is no
frame object and no hook point. A second interpreter, `callPure`, evaluates
pure calls and would not be debuggable in v1.

Gaps, in order of cost:

1. **Hook point.** Add a check before each instruction: if `ip` is in the
   breakpoint set, or the step mode says stop, suspend. Needs a measured
   cost: this is the hot loop, and the performance gates (5% median compile
   regression) apply to compile, not run, but `lume run` speed should still
   be benchmarked. Preferred shape is a separate `executeDebug` entry rather
   than a flag in `execute`, so normal runs pay nothing.
2. **Frames.** Derive call stack from `returnAddresses` plus the `line` of
   each return address. Function names come from the `"function"`
   instructions. No new runtime structure needed.
3. **Variables.** Bindings are text-encoded values (`i:`, `s:`, `f:` prefixes
   etc.). Rendering is a decode step; records, lists, and variants need a
   pretty-printer. Locals for a frame are the bindings whose key starts with
   that frame's `depth:`.
4. **Transport.** The LSP server already implements stdio JSON-RPC with
   `Content-Length` framing and has the hang/malformed-header fixes. DAP uses
   the same framing, so reuse that reader/writer.
5. **Stdout contention.** The debuggee's own `print` shares stdout with the
   protocol. Debuggee output must be captured and sent as DAP `output`
   events, or the adapter must run the debuggee over a separate channel.
   This is the main design risk.

## Proposed v1 scope

Command: `lume debug <file> [args]`, a DAP server over stdio.

In: `initialize`, `launch`, `setBreakpoints` (line, resolved to the first
instruction with that line), `configurationDone`, `continue`, `next`,
`stepIn`, `stepOut`, `pause` (between instructions), `stackTrace`, `scopes`,
`variables` (locals only), `evaluate` (variable name lookup only), `threads`
(one), `disconnect`.

Out: conditional breakpoints, watch expressions beyond a name, column
breakpoints, exception breakpoints (Lume has none), attach mode, debugging
code inside `callPure`, debugging tests under `lume test`, `.lbc`-only
programs without source.

## Milestones

1. `executeDebug` with breakpoint set and single-step, driven by a plain
   command-line harness. Verify with a Lume smoke test that steps a known
   program and asserts the line sequence.
2. Frames and variables rendering.
3. DAP wrapper with output capture over the existing stdio framing.
4. VS Code launch config / extension manifest (check whether an existing LSP
   client extension is in the repo to extend; not verified here).

## Open questions for the maintainer

- Is a separate `executeDebug` (duplicated loop, drift risk) acceptable, or
  should `execute` take an optional hook? The first is faster at runtime, the
  second avoids two copies of every opcode. Recommendation: refactor opcode
  dispatch only if it is already planned; otherwise accept the hook with a
  benchmark.
- Do `lume run` speed regressions get a gate? None is written down today.
- Is DAP the right protocol, or is a simpler `lume debug` REPL enough as a
  first deliverable? A REPL ships milestone 1 and 2 without the stdout design
  risk.

## Verification note

Findings come from reading SPEC.md section 17 and a partial read of
`execute`. I did not run the compiler or confirm how `callPure` is reached.

## Milestone 1 result

Decision taken: a hook inside `execute`, not a separate copy. `execute` is now
a wrapper over `executeWith(code, debugging, breakLines)`; the per-instruction
cost when not debugging is one Bool test.

`lume debug <file.lume> [--break line,line]` is a stdin-driven REPL, with
prompts on stderr so the program's own stdout stays separate (this sidesteps
the stdout-contention risk until the DAP wrapper). Commands: `c` continue,
`s` step in, `n` next, `o` step out, `bt`, `locals`, `p <name>`, `q`.
It starts stopped before `main`'s first instruction; EOF on stdin continues
without debugging. Covered by new cases in `test.ps1` using
`examples/debug_target.lume`.

Measured overhead on `lume run` (recursive fib(22), 6 interleaved runs each,
this machine): about 324-354 ms with the hook vs 326-336 ms for the
pre-change binary. No measurable difference at this noise level; not a
formal benchmark.

Known limits: the program's `args` still include the `--break` flag text;
`bt` prints the top frame's line from the stop position; closures share the
depth counter so `locals` inside a closure shows only that depth.
Milestones 2-4 (richer variable rendering, DAP wrapper, VS Code config)
remain.

## Milestone 2 result

`locals` and `p <name>` now go through `debugValue` instead of the raw
runtime encoding: strings are quoted, lists print as `[1, 2, 3]`, records as
`Point(x: 1, y: 2)` and enum variants as `State.busy(code: 7)` /
`State.idle`, with fields in declared order (from the record/enum schema).
Closures print as `<closure>`, function references as `fn name`, maps as
`<map of N>`; nesting is cut at depth 3 with `...`. Other kinds (bytes,
process results, durations-as-other-kinds) print as `<k>` and are not
specially rendered. Covered by `examples/debug_values.lume` in `test.ps1`.

## Milestone 3 result

`lume debug <file> --dap` speaks the Debug Adapter Protocol over stdio, using
the language server's `lspReadMessage`/`lspWriteMessage` framing. Supported
requests: `initialize`, `launch` (`program`, `stopOnEntry`), `setBreakpoints`
(line only), `configurationDone`, `threads` (one), `stackTrace`, `scopes`
(one "Locals" scope per frame), `variables`, `evaluate` (local name only),
`continue`, `next`, `stepIn`, `stepOut`, `disconnect`/`terminate`. Anything
else gets an empty success response.

Design points:
- The debug hook in `execute` calls `dapStopLoop` at each stop, which emits
  `stopped` and serves requests until one resumes execution. Frame ids are
  call depths, so a frame's locals are the bindings under that depth.
- The stdout-contention risk is resolved: in DAP mode the `print`/`eprint`
  ops send `output` events (`emitOutput`) instead of writing to stdout.
  `print` inside `callPure` (the pure-call interpreter) is not redirected.
- After the program ends the adapter sends `exited` and `terminated`, then
  waits for `disconnect`.
- Covered by a scripted session in `test.ps1` (12 assertions).

Limits: every message is sent with `seq` 0; breakpoints match by line across
the whole combined source (`use`d modules are not distinguished); `pause` is
acknowledged but cannot interrupt a running program (single-threaded
adapter); no conditional breakpoints or watch expressions; `--dap` text
still reaches the program's `args`.

**Framing bug, found and fixed:** on Windows the shared writer
(`lspWriteMessage`, used by both the language server and the DAP adapter)
emitted headers as `Content-Length: N CR CR LF CR CR LF`: its explicit CR plus
the CRT's own newline -> CR LF expansion. Strict clients cannot parse that;
the existing tests missed it because their reader skips every CR. The writer
now emits bare newlines and relies on the text-mode expansion (this toolchain
is Windows-only today), giving the required `CR LF CR LF`. `test.ps1` now reads
the raw header bytes for both `lume lsp` and `lume debug --dap` and rejects a
doubled CR (verified to fail against the pre-fix binary). Still unverified
against a real client such as VS Code.
