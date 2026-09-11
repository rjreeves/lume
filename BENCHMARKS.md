# Benchmark contract

“Quickest” and “fastest for AI” are meaningless without reproducible measurements. Lume should be compared against Lua, Python, Go, TypeScript, Bun, and a small bytecode language on the same machine.

## Compiler measurements

Measure cold and warm runs separately:

- empty program latency;
- 100, 1,000, 10,000, and 100,000 lines;
- clean package build;
- one-function incremental rebuild;
- peak resident memory;
- emitted bytecode size;
- time to first user instruction.

Report median, p95, and standard deviation over at least 30 runs. Exclude process startup only in a separately labelled persistent-daemon test.

## AI generation measurements

Use a fixed suite of at least 100 tasks across CLI, JSON, HTTP, files, database access, transformations, and error handling. For each language and model, measure:

- input tokens needed to describe the language/API;
- output tokens on the first attempt;
- first-attempt parse rate;
- first-attempt typecheck rate;
- tests passed on the first attempt;
- repair turns and repair tokens;
- wall time to the first fully correct program.

The primary metric is:

```text
total model tokens / fully correct programs
```

Secondary metrics are median wall time to correctness and first-attempt success rate. All prompts, model versions, temperatures, tasks, and test harnesses must be published.

## Acceptance gates

A feature cannot enter the core language if it causes either:

- more than a 5% regression in median clean compile time; or
- more than a 3% regression in AI tokens-to-correctness;

unless it improves task success enough to offset the regression on the published suite.
# Real 10,000-line benchmark

Run the fixed-size compiler benchmark with:

```powershell
.\benchmark-10000.ps1
```

It generates one valid 10,000-line Lume program, validates it, warms the
compiler, and reports latency and source-lines per second across repeated runs.
The generated source is placed under `dist\`.

## Generic data pipeline benchmark (2026-09-09)

The 10,000-line benchmark was run for 10 iterations after each compiler stage:

| Stage | Mean compile | Lines/second | Bytecode load |
| --- | ---: | ---: | ---: |
| Generic function substitution | 310.9 ms | 32,165 | 6.2 ms |
| Generic records/enums and built-in option/result types | 301.5 ms | 33,167 | 6.2 ms |
| `map`, `filter`, `find`, and `fold` | 317.1 ms | 31,536 | 4.7 ms |
| `?` result propagation | 325.0 ms | 30,769 | 4.7 ms |
| Final validation pass (30 runs) | 309.9 ms | 32,268 | 5.2 ms |

## Post-closures/protocols/test-runner check (2026-09-11)

Re-run after closures, generic constraints, marker protocols, and the native
test runner were added (2026-09-10), to check whether that work regressed
the fixed-size benchmark:

| Run | Mean compile | Lines/second | Bytecode load |
| --- | ---: | ---: | ---: |
| 20 iterations | 310.95 ms | 32,160 | 4.65 ms |

No regression against the 2026-09-09 baseline — this benchmark's generated
program is 10,000 lines of `total = total + 1`, though, so it exercises none
of the new syntax and cannot actually confirm those features are free; it
only confirms the new parser branches don't slow down code that never
touches them. It also still sits at **~31x over** the README's original
"10,000 lines in under 10 ms" design target, unchanged since the first
measurement — this benchmark's own "10,000 lines/second" bar (a ~1,000 ms
budget) is a materially looser goalpost than that original target, and
passing it (`TargetMet: True`) should not be read as validating the
headline claim.

Every stage remained above the 10,000-lines/second design target. Timing noise is
expected from short desktop runs; use a larger iteration count for release
comparisons.

## Representative feature-mix benchmark (2026-09-11)

Every benchmark above generates the same trivial workload: 10,000 lines of
`total = total + 1`, one reused `var`. That shape cannot expose costs that
scale with *how many distinct things a real program declares*, because it
only ever has one binding in scope. `benchmark-10000-features.ps1` generates
a different 10,000-line program instead — ~904 repetitions of a block that
mixes records, an enum matched with `match`, a marker-protocol constraint, a
user-defined generic function, an inline closure capturing a `let`, and
`list.map`/`filter`/`fold` with both `&name` references and a closure, each
repetition using unique binding names (`items1`, `items2`, ...). This is
much closer to what an actual Lume program's `main` looks like.

```powershell
.\benchmark-10000-features.ps1 -Iterations 1
```

| Benchmark | Mean compile | Lines/second | vs. trivial baseline |
| --- | ---: | ---: | ---: |
| Trivial (`benchmark-10000.ps1`) | 310.95 ms | 32,160 | baseline |
| Representative feature mix | 21,563 ms | 464 | **~69x slower** |

This fails the benchmark's own "10,000 lines/second" bar outright
(`TargetMet: False`) — the trivial benchmark's `TargetMet: True` was never
telling you anything about programs that look like this.

**Isolating the cause.** Two follow-up control files (10,000 lines each,
`lume check` timed standalone) narrow down which construct drives the ~69x:

| Control | Contents | `lume check` wall time | vs. trivial baseline |
| --- | --- | ---: | ---: |
| Trivial | one reused `var` | 0.31 s | baseline |
| Unique bindings | ~9,996 distinct `let x{i} = {i}`, no other features | 2.6 s | ~8x |
| Closures only | ~4,998 `list.map(items, fn(v) -> int => v + 1)` calls | 32.2 s | ~104x |

Declaring many distinct bindings alone costs something (~8x), consistent
with a duplicate-binding check that scans all prior names in scope for each
new one — an O(n²) shape as a function's binding count grows. But
**closures specifically are far more expensive than plain bindings**, even
at roughly half the binding count of the unique-bindings control: passing
an inline closure to `list.map` requires checking what it captures against
the enclosing scope, and that check's cost appears to compound as the
enclosing scope grows across thousands of closures in the same function.

**A more serious finding than the timing:** running this program through
`lume benchmark <path> 20` (the repeated in-process compile loop the other
tables in this file use) does not just run slowly — it crashes with `certo
panic: out of memory` before completing. A single `lume check` of the same
file succeeds in ~23s, so the crash is not inherent to compiling one
instance of this program; it is the `benchmark` command's in-process
iteration harness retaining memory across iterations on a workload heavy
enough to expose it. `benchmark-10000-features.ps1` therefore defaults to
`-Iterations 1` rather than 20.

**Takeaway:** the published "10,000 lines/second" and "~31x over the
original 10ms target" numbers elsewhere in this file describe a workload no
real Lume program resembles. On code that actually declares the number of
distinct bindings and closures a real 10,000-line program would, compile
time is roughly 69x worse than the trivial benchmark suggests, and the
compiler's own benchmarking tool cannot survive repeated measurement of it.
Closures are implicated as the largest single contributor found in the mix
above; generics and protocols are isolated separately below.

## Generics vs. protocols isolation (2026-09-11)

The feature mix also uses a user-defined generic function and a
protocol-constrained generic function, so the natural next question is
which of those two costs anything. Four more 10,000-line control files
(~9,992–9,996 unique bindings each, `lume check` timed standalone) separate
"generic" from "constrained" from "constrained by a user protocol":

| Control | Call shape | `lume check` wall time | vs. trivial baseline |
| --- | --- | ---: | ---: |
| Trivial | one reused `var`, no calls | 0.31 s | baseline |
| Plain call | `fn plain(value: int) -> int`, non-generic | ~4.2 s | ~1.6x |
| Unconstrained generic | `fn identity<T>(value: T) -> T` | ~31.3 s | ~12x |
| Built-in-marker-constrained generic | `fn keep_number<T: Number>(value: T) -> T` | ~6.3 s | ~2.4x |
| User-protocol-constrained generic | `fn tag<T: Sized>(value: T) -> T`, empty marker `protocol`/`impl` | ~31.6 s | ~12.2x |

Each number is the mean of two runs; all four were reproducible run to run.

**It is not "generics" or "protocols" as a category — it is specifically
how the constraint gets resolved.** An unconstrained type parameter and a
type parameter constrained to a user-declared protocol cost almost exactly
the same (~31s, statistically indistinguishable across reruns) — about 5x
more than a type parameter constrained to one of the four built-in markers
(`Eq`, `Ord`, `Number`, `Text`), which lands at ~6.3s. The only
interpretation consistent with that pattern: the four built-in markers get
a fast path, almost certainly a direct name check against that fixed list.
A user-declared `protocol`/`impl` constraint isn't on that list, so it
falls through to whatever general mechanism handles an *unconstrained* type
parameter — and that fallback, not "having a protocol," is the expensive
part. **Constraining a generic function to your own protocol currently buys
no compile-time benefit over not constraining it at all.**

This was measured against the marker-only protocol model on `main` as of
this writing (empty `protocol {}` / `impl ... for ... {}` bodies, no
methods). A separate, not-yet-merged change adds real method signatures to
protocols with static dispatch to concrete `Type.method` functions — a
different enough mechanism that this result should be re-measured once that
lands rather than assumed to still hold.

Record/enum construction at this scale still hasn't been isolated
individually.
