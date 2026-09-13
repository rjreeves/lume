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

Declaring many distinct bindings alone costs something (~8x). *(Revised
below: a later, direct isolation shows this is not primarily a
duplicate-binding-name check, and that even the "trivial" reused-`var`
baseline in this very table is itself superlinear, not flat — see
"Isolating the duplicate-binding scan directly".)* **Closures specifically
are far more expensive than plain bindings**, even at roughly half the
binding count of the unique-bindings control: passing an inline closure to
`list.map` requires checking what it captures against the enclosing scope,
and that check's cost appears to compound as the enclosing scope grows
across thousands of closures in the same function.

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

**That change has since landed** (`Add protocol methods with static
dispatch`), and re-measuring confirms the result above no longer holds —
see below.

## Generics vs. protocols, re-measured after protocol methods (2026-09-11)

Same four control files, re-run against `main` after protocol methods with
static dispatch merged:

| Control | `lume check` wall time (before → after) | vs. trivial baseline (2.6 s) |
| --- | --- | ---: |
| Unconstrained generic | 31.3 s → **~13.9 s** | ~5.3x |
| Built-in-marker-constrained generic | 6.3 s → **~13.8 s** | ~5.3x |
| User-protocol-constrained generic | 31.6 s → **~13.1 s** | ~5.0x |

Each new number is the mean of at least two runs, reproducible run to run,
same as before.

**The fast path for built-in markers is gone, and it went the wrong
direction.** Previously, built-in-constrained generics were the cheap
option (~2.4x baseline) and unconstrained/user-protocol-constrained ones
were the expensive outliers (~12x). Now all three have converged to
roughly the same cost (~13–14s, ~5x baseline) — the built-in markers got
*more* expensive rather than the other two getting cheaper to match them.
This is consistent with constraint resolution being refactored into one
shared, more expensive path as groundwork for the roadmap's next milestone
("allow a function constrained by `T: Protocol` to invoke protocol methods
on values of `T`") — plausible from the timing shift, but not confirmed by
reading the implementation diff. The practical upshot is unchanged in
spirit either way: **no combination of constrained/unconstrained generics
is cheap**, and which one you pick no longer even matters, since they all
now cost about the same.

This is exactly why a "not yet merged" caveat is worth writing down instead
of silently trusting a result to still hold, and why this file re-measures
rather than assuming a number survives across a compiler version it wasn't
taken on.

## Record and enum construction isolation (2026-09-11)

Four more 10,000-line control files (same shape as the generics controls:
~9,992–9,996 unique bindings each, `lume check` timed standalone), this
time isolating record construction, enum construction (with and without a
payload), and record `with`-updates — the remaining constructs from the
representative feature-mix benchmark that hadn't been isolated yet:

| Control | Construct | `lume check` wall time | vs. trivial baseline (2.6 s) |
| --- | --- | ---: | ---: |
| Enum construction, zero payload | `Color.red()` | 3.5 s | ~1.4x |
| Plain function call (reference point) | `plain(value)` | ~4.1 s | ~1.6x |
| Enum construction, with payload | `Tagged.value(n: i)` | 5.6 s | ~2.2x |
| Record `with`-update | `base with { x: i }` | 5.9 s | ~2.3x |
| Record construction | `Point(x: i, y: i)` | 7.9 s | ~3.0x |

Each number is the mean of at least two runs, reproducible run to run.

**Records and enums are cheap — nowhere near the generics/closures tier.**
The most expensive of the five, plain record construction, is under 3x
baseline; every generic-constraint variant above costs at least 5x, and
closures cost ~104x (measured earlier in this file). There's a small,
sensible internal gradient: zero-payload enum construction (~1.4x) is
*cheaper than an ordinary function call*, because `Color.red()` has no
argument list to validate at all, while even a 1-argument call goes through
full call-argument type-checking. Payload-carrying enum construction
(~2.2x) and record construction (~3.0x) cost progressively more as field
count grows, consistent with per-field schema validation. `with`-update
(~2.3x) sits right alongside payload-carrying enum construction — not
meaningfully worse than plain record construction.

**Where this leaves the full isolation matrix**, all measured on the same
compiler build (after protocol methods with static dispatch merged):

| Variant | `lume check` time | vs. baseline |
| --- | ---: | ---: |
| Baseline (no calls) | 2.6 s | — |
| Enum construction, zero payload | 3.5 s | ~1.4x |
| Plain function call | ~4.1 s | ~1.6x |
| Enum construction, with payload | 5.6 s | ~2.2x |
| Record `with`-update | 5.9 s | ~2.3x |
| Record construction | 7.9 s | ~3.0x |
| Unconstrained / built-in-constrained / user-protocol-constrained generic | ~13.1–13.9 s | ~5.0–5.3x |
| Closures (list.map, ~half the binding count) | 32.2 s | ~104x |

If someone wanted to close the compile-time gap, this ranking says where to
look first: closures by a wide margin, then the now-unified (and now more
expensive) generic-constraint resolution path. Records, enums, `with`, and
plain calls are all clustered within 3x of baseline and are not where the
problem lives.

## Closure scaling isolation (2026-09-11)

Every closure number above is a single data point at one size (10,000
lines), which can't distinguish "expensive but linear" from "expensive and
getting worse as programs grow" — the distinction that actually matters for
whether this is safe to build large programs against. Three families of
control file, swept across N = 250 / 500 / 1,000 / 2,000 / 4,000 (no fixed
line-count padding — just N repetitions of one shape, `lume check` timed
standalone), separate plain bindings from non-capturing closures from
capturing closures:

| N | Plain bindings | Non-capturing closure | Capturing closure |
| ---: | ---: | ---: | ---: |
| 250 | 0.021 s | 0.096 s | 0.123 s |
| 500 | 0.040 s | 0.327 s | 0.434 s |
| 1,000 | 0.057 s | 1.170 s | 1.630 s |
| 2,000 | 0.130 s | 5.17 s | 7.05 s |
| 4,000 | 0.458 s | 21.16 s | 31.95 s |

The 2,000 row was reproduced on a second run for both closure variants
(5.16 s and 7.09 s) before trusting the trend.

**The doubling ratio is the signal that matters, not the absolute time.** A
true O(n²) algorithm produces exactly 4x more work every time N doubles,
regardless of N:

| N doubling | Non-capturing | Capturing |
| --- | ---: | ---: |
| 250 → 500 | 3.4x | 3.5x |
| 500 → 1,000 | 3.6x | 3.8x |
| 1,000 → 2,000 | 4.4x | 4.3x |
| 2,000 → 4,000 | 4.1x | 4.5x |

The ratio climbs toward 4x and holds there once N is large enough that
fixed overhead stops dominating (noise dominates at N ≤ 500, where absolute
times are tens of milliseconds). **This is a clean quadratic signature.**
Plain bindings, over the same range, only reach ~3.5x per doubling at
N = 4,000 and are two orders of magnitude faster in absolute terms
throughout — closures carry their own, much steeper cost curve, not just
the same duplicate-binding-scan cost bindings already pay plus a flat tax.

**The quadratic cost is not specific to capturing.** This overturns the
original hypothesis in this file (an expensive per-closure scan of the
enclosing scope for capture-safety): a closure that captures nothing at all
(`fn(value: int) -> int => value + 1`) shows the *same* ~4x-per-doubling
curve as one that captures a `let`. Whatever is quadratic here happens for
every closure passed to `list.map`/`filter`/`find`/`fold`, regardless of
what it references.

Capturing does add something real on top, just not a second quadratic term:
at every N, the capturing variant is a fairly stable **~1.3–1.5x** more
expensive than the non-capturing one at the same N (1.28x at N = 250, 1.51x
at N = 4,000) — consistent with one bounded extra check per closure
(confirming the captured binding is `let`, not `var`), riding on top of the
same underlying quadratic cost rather than compounding it further.

**Practical implication:** a Lume program that builds up many `list.map`/
`filter`/`fold` closures in one function — a natural pattern in real
automation scripts — does not merely pay a fixed per-closure cost; each
additional closure in the same scope makes every other closure in that
scope more expensive to check. This is the single most actionable finding
in this file: unlike record/enum construction (cheap and apparently
linear), the closure cost compounds specifically as a function's closure
count grows, which is exactly the shape that turns "slow" into "unusable"
as a codebase scales.

*Correction, see the next section: the "generics-constraint cost (expensive
but flat per call)" comparison originally made here was wrong.* A proper
scaling sweep shows generic calls are quadratic too — the "flat per call"
read came from comparing two single-size data points, the same mistake this
file already corrected once for the trivial 10,000-line benchmark.

## Generics scaling isolation (2026-09-11)

The same question the closure sweep answered — "is this expensive-but-flat,
or expensive-and-worsening?" — hadn't been asked of generics yet. Every
earlier generics number (the built-in-vs-user-protocol isolation, and its
post-protocol-methods re-measurement) was a single data point at one size.
Two control families — plain non-generic calls and unconstrained generic
calls (`fn identity<T>(value: T) -> T`, no constraint syntax at all) —
swept across N = 250 / 500 / 1,000 / 2,000 / 4,000 / 8,000, `lume check`
timed standalone:

| N | Plain call | Unconstrained generic call |
| ---: | ---: | ---: |
| 250 | 0.023 s | 0.028 s |
| 500 | 0.042 s | 0.061 s |
| 1,000 | 0.081 s | 0.149 s |
| 2,000 | 0.202 s | 0.487 s |
| 4,000 | 0.675 s | 1.948 s |
| 8,000 | 2.57 s | 8.65 s |

N = 8,000 was reproduced on a second run for both (2.593 s / 2.546 s and
8.670 s / 8.628 s) before trusting it.

| N doubling | Plain call | Generic call |
| --- | ---: | ---: |
| 250 → 500 | 1.8x | 2.2x |
| 500 → 1,000 | 1.9x | 2.4x |
| 1,000 → 2,000 | 2.5x | 3.3x |
| 2,000 → 4,000 | 3.3x | 4.0x |
| 4,000 → 8,000 | 3.8x | 4.4x |

**Both curves are quadratic.** Both doubling ratios climb toward and settle
near 4x, the same O(n²) signature the closure sweep found (smaller N is
noise-dominated by fixed process overhead). This was cross-checked by
extrapolating each curve from N = 8,000 up to N ≈ 9,992 — the size of the
original full 10,000-line generics comparison — using pure N² scaling:
predicted plain ≈ 4.0 s, predicted generic ≈ 13.5 s, against the actual
measured 4.1 s and 13.9 s. The quadratic model doesn't just look right, it
quantitatively accounts for every number measured so far across both
generics benchmarks in this file.

**This isn't a "generics" problem — it's a shared per-statement compilation
cost every function pays, and generics inherit it.** Every control file in
this sweep, generic or not, declares N distinct `let` bindings — at the
time this section was written, that was believed to be the specific driver
(a duplicate-binding-name scan). *A later, direct isolation (see "Isolating
the duplicate-binding scan directly", below) shows that belief was wrong:
even a function with zero distinct bindings — one `var` reassigned N
times — shows the same quadratic curve. The real shared cost is something
that happens on every statement regardless of whether it declares a
binding at all*, most likely how the compiler accumulates its growing
per-function instruction list. A plain, non-generic function call already
shows the same quadratic curve on its own for that reason. Generics don't
introduce a different algorithmic shape on top of that — they pay a bigger
constant on the *same* shape: the generic/plain ratio at each N (1.2x,
1.5x, 1.8x, 2.4x, 2.9x, 3.4x) is still drifting upward at N = 8,000, not
clearly flat, but its own growth is far slower than the underlying
quadratic (each doubling only moves the ratio ~1.2x, not ~4x) — consistent
with a larger per-statement cost rather than a separate superlinear term,
though a small additional generic-specific factor can't be ruled out from
six points alone.

**Revised bottom line, superseding "generics are slow" from earlier in this
file**: any function with many *statements* — not specifically many
distinct bindings — gets quadratically slower to compile, full stop;
generics, closures, and even plain function calls all ride the same
underlying cost curve, and unique bindings add a real but secondary
multiplier on top of it. See the next section for the direct isolation
that pins this down, which further revises "duplicate-binding/declaration-
scan cost" down to a secondary factor rather than the root cause.

## Isolating the duplicate-binding scan directly (2026-09-11)

Every prior explanation in this file for the O(n²) shape pointed at the
same suspect: a duplicate-binding-name check that scans every name already
in scope each time a new `let`/`var` is declared. That was always an
inference from indirect evidence (bindings, generics, and closures all
happened to declare many distinct names). This section tests it directly,
by removing bindings from the equation entirely.

Two control families, swept across N = 250 / 500 / 1,000 / 2,000 / 4,000 /
8,000, `lume check` timed standalone:

- **Reused var**: one `var total = 0`, then N statements of
  `total = total + 1`. Zero new bindings after the first — the "names in
  scope" list never grows past length 1, so a duplicate-check against it
  should be O(1) per statement, O(n) overall, if that check were really the
  driver.
- **Unique bindings**: N statements of `let x{i} = i`, a fresh distinct
  binding every time — the case that should isolate exactly what the
  suspected mechanism does.

| N | Reused var | Unique bindings |
| ---: | ---: | ---: |
| 250 | 0.020 s | 0.022 s |
| 500 | 0.031 s | 0.035 s |
| 1,000 | 0.046 s | 0.059 s |
| 2,000 | 0.079 s | 0.140 s |
| 4,000 | 0.188 s | 0.442 s |
| 8,000 | 0.614 s | 1.694 s |

N = 4,000 and N = 8,000 were each reproduced on a second run for both
variants before trusting the trend.

| N doubling | Reused var | Unique bindings |
| --- | ---: | ---: |
| 250 → 500 | 1.55x | 1.59x |
| 500 → 1,000 | 1.48x | 1.69x |
| 1,000 → 2,000 | 1.72x | 2.37x |
| 2,000 → 4,000 | 2.37x | 3.15x |
| 4,000 → 8,000 | 3.27x | 3.84x |

**This disproves the duplicate-binding-scan hypothesis rather than
confirming it.** If that scan were the primary cause, the reused-var
column should stay near a flat 2.0x every doubling (true O(n) — the
"names" list it scans against never exceeds length 1). It doesn't: its
ratio climbs to 3.27x by N = 8,000, converging toward the same ~4x ceiling
as unique bindings. **A function with zero distinct bindings is already
quadratic.** Whatever's actually driving this cost happens once per
*statement*, regardless of whether that statement introduces a name —
the leading candidate is how the compiler accumulates its growing
per-function bytecode instruction list (`appendCode`/`List.push`, invoked
once per compiled statement): if that operation isn't O(1) amortized, every
function with N sequential statements is O(n²) before a single binding,
generic, or closure is involved.

The duplicate-binding scan isn't nothing, though. The unique/reused ratio
at each N (1.10x, 1.13x, 1.28x, 1.77x, 2.36x, 2.76x) is itself climbing,
so declaring unique names is measurably, increasingly worse than reusing
one. But it rides on top of a quadratic floor that exists independent of
it, as a secondary multiplier — not as the source of the quadratic shape
itself, which is what every earlier section in this file (before this one)
assumed.

**This is the actual root cause this whole investigation has been
converging toward, now isolated directly instead of inferred**: a
per-statement compilation cost, most likely bytecode-list accumulation,
that is quadratic in a function's statement count on its own, before
accounting for bindings, generics, or closures at all. Everything measured
in this file — generics' ~5x, closures' ~104x, records/enums' ~3x — is a
multiplier stacked on top of this shared floor, not an independent
mechanism. Fixing *this* would improve every number in this file at once;
fixing any single feature's multiplier would not.

## Fixing the two identified binding-scope bugs (2026-09-11)

The previous section isolated the shared quadratic floor but explicitly
left it unfixed. Separately, two concrete, source-confirmed bugs in the
*unique-bindings* multiplier on top of that floor were found and fixed in
`compileBlock` (`src/lume.cto`):

**Bug 1 — `List.push` instead of `List.pushMut` for `names`/`mutables`.**
Certo's `List.push` reallocates and copies the *entire* list on every call
(confirmed by reading `certo_list_push` in Certo's own
`crates/stdlib/src/collections.rs` — a genuine O(n) "functional update"),
while `List.pushMut` grows geometrically in place, genuinely O(1)
amortized. `compileBlock` used the copying version for every `let`/`var`
declaration. Fixed by making `compileBlock` take an explicit, independent
copy of `initialNames`/`initialMutables` once at entry (`List.slice`, not
an alias) and using `List.pushMut` for every subsequent growth within that
call. The explicit copy is required, not optional: `compileBlock` recurses
for nested `if`/`while` blocks, passing the current scope's `names`/
`mutables` down as the nested call's `initialNames`/`initialMutables` — if
that were an alias rather than a copy, a binding declared inside a nested
block would mutate the same buffer the enclosing scope still holds,
silently leaking into it.

**Bug 2 — `containsName`'s linear scan.** Every duplicate-binding check
(and every "undefined binding" / "cannot assign to immutable" check) was a
full linear scan of the current `names`/`mutables` list, independent of
bug 1's list-growth cost. Certo's `Map<K,V>` cannot fix this: it hashes on
raw *pointer* identity, not text content (`crates/stdlib/src/
collections.rs`'s own header comment: "Map (open-addressing, pointer-
equality keys)"), so two separately-lexed occurrences of the same
identifier text — the normal case, since `Text.slice` allocates a fresh
string each time — would not compare equal as map keys; and
`certo_map_insert` is itself copy-on-write, so it would give no complexity
benefit even if the key problem didn't exist. A sorted-list-plus-binary-
search alternative was also considered and rejected: maintaining sort order
requires shifting every element after the insertion point, an O(n) cost
per insert that just moves the bottleneck from lookup to insert without
changing the overall complexity class.

The actual fix: a small hand-rolled hash set, entirely within
`src/lume.cto` (`bucketCount`, `characterIndex`, `hashName`,
`emptyBuckets`, `seedBuckets`, `bucketsContains`, `insertBucket`) —
1024 fixed buckets, each a `List<Text>`, hashed via a polynomial hash over
each character's position in a reference alphabet (there being no built-in
string-hash or char-to-int function available for `Text`). `compileBlock`
seeds a bucket set from its already-copied `names`/`mutables` at entry
(same aliasing-safety requirement as bug 1) and uses it for the duplicate/
undefined/immutable checks instead of `containsName` directly. This is a
constant-factor improvement, explicitly not an asymptotic one: with a
*fixed* bucket count, average bucket occupancy still grows with a
function's binding count, so a lookup is O(n / 1024), not true O(1). A
genuinely scale-invariant fix needs dynamic resizing/rehashing, which was
judged not worth the added correctness risk for this pass.

**Correctness, verified before trusting either fix**: the full smoke suite
(`test.ps1`) passes unchanged (same one pre-existing, unrelated CRLF-byte
failure as every other entry in this file); `examples/task_board.lume`
produces identical output; and a hand-written stress test specifically
targets the aliasing risk bug 1 and bug 2's copy-once step both depend on —
a binding declared inside a nested `if` block, followed by the *same name*
redeclared in the outer scope, followed by two *sibling* `if` blocks each
independently declaring the same name — passes exactly as it should (no
leak into the outer scope, no false cross-contamination between siblings).
All three error paths gated by the new bucket lookups (`E0211` duplicate
binding, `E0210` undefined binding, `E0215` assignment to immutable) still
fire correctly.

**Performance result — real, but does not change the complexity class:**

| N | Original | After bug 1 (pushMut) | After bug 2 (hash buckets) |
| ---: | ---: | ---: | ---: |
| 250 | 0.022 s | 0.021 s | 0.021 s |
| 500 | 0.035 s | 0.026 s | 0.026 s |
| 1,000 | 0.059 s | 0.052 s | 0.042 s |
| 2,000 | 0.140 s | 0.108 s | 0.105 s |
| 4,000 | 0.442 s | 0.386 s | 0.350 s |
| 8,000 | 1.694 s | 1.569 s | 1.351 s |

Total improvement at N = 8,000: **~20%**. Real, and cheap to keep, but the
doubling ratios tell the more important story:

| N doubling | Original | After bug 1 | After bug 2 |
| --- | ---: | ---: | ---: |
| 250 → 500 | 1.59x | 1.24x | 1.24x |
| 500 → 1,000 | 1.69x | 2.00x | 1.62x |
| 1,000 → 2,000 | 2.37x | 2.08x | 2.50x |
| 2,000 → 4,000 | 3.16x | 3.57x | 3.33x |
| 4,000 → 8,000 | 3.83x | 4.06x | 3.86x |

All three still converge to ~4x at N = 8,000 - still quadratic, both fixes
applied. **This means neither bug was the dominant cost.** Both fixes
specifically targeted binding-tracking machinery; the section above already
established that even a program with *zero* bindings (`total = total + 1`
repeated, or `print(1)` repeated) is independently quadratic. The ~20%
recovered here is consistent with removing the binding-specific overhead
from a total that was mostly something else all along - something in the
shared per-statement compilation path, not yet located. Finding it would
need actual profiling instrumentation rather than more source reading or
black-box wall-clock sweeps, which is where this investigation's diagnostic
tools available in this environment reach their limit.

**Bottom line**: both fixes are correct, verified, and worth keeping on
their own merits - they resolve genuine O(n) operations that had cheaper
O(1)-amortized or O(1)-average alternatives available. But they are not
the fix for this file's headline finding. The dominant, still-unlocated
cost affecting every measurement in this file remains open.

## The dominant cost, located: `lex()` (2026-09-11)

The previous section explicitly deferred locating the shared quadratic
floor, on the grounds that source reading and black-box wall-clock sweeps
had reached their limit. Direct instrumentation (temporary `monotonicMillis`
timers added around every major phase of `compileSource`/`compile`/
`compileBlock`, run against the same `print(1)` × N control used
throughout this file, then reverted before committing anything) settles it.

| N | Total tokens | `lex()` time | Every other instrumented phase | Total `check` time |
| ---: | ---: | ---: | ---: | ---: |
| 1,000 | 5,020 | 0 ms | 0 ms | 26 ms |
| 2,000 | 10,020 | 16 ms | 0 ms | 42 ms |
| 4,000 | 20,020 | 16 ms | 0 ms | 96 ms |
| 8,000 | 40,020 | **94 ms** | 0 ms | 292 ms |

"Every other instrumented phase" is `parseComparison`, `validateExpression`,
`appendCode`, the entire `compileBlock` call as one unit, `verifyTypes`, and
`scanRecords`/`scanEnums`/`scanFunctions` - each measured at 0 ms even at
N = 8,000. **`lex()` is the only phase that shows any cost at all**, and its
own growth (16 ms → 94 ms, ~5.9x for a 2x token-count increase) is itself
clearly superlinear, not just a large constant.

**Located mechanism, source-confirmed**: Certo's `certo_text_slice`
(`crates/stdlib/src/text.rs`, the runtime backing `Text.slice`) calls
`strlen(s)` unconditionally on every invocation, where `s` is whatever
`Text` value was passed as the *first* argument - regardless of how small
the requested slice range is:

```c
certo_text_t certo_text_slice(certo_text_t s, int64_t start, int64_t end) {
    if (!s) return "";
    int64_t n = (int64_t)strlen(s);   /* scans the WHOLE string, every call */
    ...
```

Lume's lexer calls `Text.slice(source, start, index)` once per identifier
and number token, and `source` is always the *entire file* being lexed, not
the token. Every token's slice call therefore re-scans the whole file just
to clamp bounds the lexer's own `while index < sourceLength` loop had
already guaranteed valid. Tokenizing a file with N identifier/number tokens
costs O(file-length) per token, i.e. O(N²), before a single byte of parsing,
type-checking, or bytecode emission happens - fully explaining why every
control in this file, including ones with zero bindings, generics, or
closures, showed the same quadratic floor.

**Caveat, stated plainly rather than overclaimed**: an attempt to reproduce
this mechanism in an isolated Certo microbenchmark (fixed tiny slice size,
varying only the source string's length) gave inconsistent results across
two different string-construction methods - one showed a 1.375-second cost
for 50,000 calls that should take microseconds (consistent with the
theory), another showed 0 ms at a comparable final size (most likely the
compiler hoisting a loop-invariant call in a synthetic loop too trivial to
defeat that optimization, or a memory-fragmentation artifact in the first
method's own O(n²) string-building setup - not evidence against the
theory, just an inconclusive isolation attempt). The located-in-context
evidence (`lex()` measured directly, inside the real compiler, against real
source) is strong and unambiguous; the specific mechanism is the most
plausible explanation consistent with that evidence and with reading the
exact function being called, but was not independently proven in a clean,
minimal repro.

**This is a Certo runtime bug, not a `lume.cto` bug** - `certo_text_slice`
is Certo's own stdlib, not something this repository can fix. Filed as
Certo BACKLOG.md item 325 for that project to act on. All diagnostic
instrumentation used to locate this was reverted before this was written;
nothing in this section changed `src/lume.cto`.

**Correction to this section's own closing claim, see below**: "fixing the
lexer would improve every number in this file at once" turned out to be
wrong for closures and generics specifically. It was a real, large, and
worth-fixing floor - just not the *only* one.

## The lexer fix landed; closures and generics turned out to have their own, separate mechanisms too (2026-09-11)

Certo's own team fixed item 325 fast: `Text.sliceUnchecked` (mirroring
`Text.byteAtUnchecked`'s "caller already validated bounds" contract) shipped
the same day it was filed. This repository's lexer was updated to call it at
its three `Text.slice(source, ...)` call sites (the two identifier/number
token sites, plus a third, previously-unnoticed one: the two-character
operator lookahead, whose bounds are equally guaranteed by its own preceding
`index + 1 < sourceLength` guard).

**The shared floor is genuinely gone, and the complexity class changed, not
just the constant:**

| Benchmark | Before | After | Improvement |
| --- | ---: | ---: | ---: |
| Trivial (`benchmark-10000.ps1`, mean compile) | 310.95 ms | **44.55 ms** | ~7.0x |
| Trivial (lines/second) | 32,160 | **224,467** | ~7.0x |
| `print(1)` × 8,000 doubling ratio | ~4.0x (quadratic) | **~1.55–1.9x** (near-linear, confirmed out to N = 32,000) | complexity class changed |

**But the representative feature-mix benchmark barely moved** (21,563 ms →
14,125 ms, ~35% faster, nowhere near ~7x) — because its dominant cost was
never the lexer. Re-checking closures and generics in isolation after the
lexer fix landed:

| Workload | Doubling ratio before | Doubling ratio after lexer fix alone |
| --- | ---: | ---: |
| Capturing closures | ~4.3–4.5x | **~4.2–4.4x** (still quadratic) |
| Unconstrained generics | ~4.0–4.4x | **~3.4–3.7x** (still quadratic) |

Both got a real, modest constant-factor improvement (~20–30%, since they
lex their own bodies too) but kept their own complexity class. **This means
closures and generics each ride at least one more quadratic mechanism of
their own, independent of the lexer** — contradicting this section's
original prediction that the lexer was the whole story.

### A second bug, found and fixed: `verifyTypes`' own `Bindings` (Lume-side, not Certo's)

Instrumenting `verifyTypes` directly (temporary timers, same technique,
reverted before committing) showed it dominating both remaining workloads —
1,281 ms of generics' 1,324 ms total at N = 4,000; 4,516 ms of closures'
4,613 ms at N = 2,000. Tracing why: `verifyTypes` maintains its own
`Bindings` structure (distinct from `compileBlock`'s `names`/`mutables`,
already fixed in the previous section) for tracking each `let`/`var`'s
type during whole-program verification, and it has the *exact same*
two-part bug in a third, previously untouched location:

- `findBinding` — a plain linear scan, called on every `load`/`store`.
- `putBinding` — grows via `List.push` (Certo's O(n)-copying version),
  called on every `param`/`store`.

**This one could not be fixed with the same "copy once at entry, then
`pushMut`" pattern used for `compileBlock`.** A match arm's payload binding
(`Some(value) => ...`) has a genuine, functionally necessary rollback
requirement — `MatchContext.baseBindings` is restored via
`bindings = matchState.baseBindings` at every arm transition, relying on
`putBinding`'s non-mutating `List.push` to leave the saved snapshot
untouched. Switching that to `pushMut` would corrupt the snapshot the same
way naively switching `compileBlock`'s own `names`/`mutables` would have
without first copying them.

The fix instead splits the two cases: a new fixed-bucket hash structure
(`bindingBucketGet`/`insertBindingBucket`, reusing the same
`hashName`/`bucketCount`/`emptyBuckets` machinery from the `compileBlock`
fix, entries encoded as `"name=value"` per bucket) now handles `param` and
top-level `store` bindings — which only ever accumulate within one
function and never need rollback — while match-arm payload bindings
continue to flow through the original, untouched `Bindings`/`putBinding`/
`getBinding` mechanism. A lookup checks the fast buckets first and falls
back to the original mechanism only for the rare, arm-count-bounded (not
N-scaling) payload case.

One subtlety this surfaced: closures emit their own `param` instructions
(sharing the same handler as top-level function parameters), and a
`List<Text>` bucket has no in-place "update at index" the way `putBinding`
used to overwrite an existing entry — so two separate closures in the same
function both naming their parameter `value`, each with a different type
(a very common pattern: `list.map(a, fn(value: int) => ...)` and
`list.map(b, fn(value: str) => ...)` in the same function), would have
resolved to whichever closure's type happened to be inserted *first* if
the lookup stopped at the first match. Fixed by having the lookup scan the
whole bucket and keep the *last* match instead, matching `putBinding`'s
original "overwrite on existing name" behavior exactly rather than
"append and shadow."

**Verified correct**, not just fast: full smoke suite green (same one
pre-existing, unrelated CRLF failure), `task_board` output byte-identical,
and two new targeted stress tests pass — two closures in the same function
reusing the parameter name `value` with different types (`int` and `str`)
each resolve to their own correct type; a match-arm payload binding named
`msg` is correctly rolled back so a later, unrelated outer-scope `let msg`
of the same name resolves correctly rather than picking up the payload's
stale value.

**Performance result — another real improvement, still not the dominant
remaining cost:**

| Workload | Before any fix | After lexer fix | After `verifyTypes` fix | Doubling ratio now |
| --- | ---: | ---: | ---: | ---: |
| Closures (N=2,000 → 4,000) | 7.05 s / 31.95 s | 5.27 s / 22.08 s | **4.61 s / 18.74 s** | still ~4.1–4.3x |
| Generics (N=2,000 → 4,000) | 0.487 s / 1.948 s | 0.402 s / 1.503 s | **0.338 s / 1.324 s** | still ~3.3–3.9x |

Another real, modest (~12–16%) improvement. **Both workloads are still
clearly quadratic.** This was not the dominant remaining cost for either.

### Two remaining mechanisms, identified but deliberately left unfixed

**Closures**: tracing the remainder re-confirmed a mechanism flagged
earlier in this file's own closure-scaling section (before the lexer bug
was found) and never actually fixed: `validateExpression`'s
`activeNames = names` is a plain *alias* of the enclosing function's own
growing name list, not a copy, and every closure or match arm's parameter
registration does `activeNames = List.push(activeNames, parameter)` — the
same non-mut-growth bug, in a fourth location. Unlike the two bugs already
fixed, this one resists the same "copy once, then `pushMut`" trick: the
closure/match-arm save-and-restore here (`closureScopes`/`matchScopes`) is
the actual scope-leak correctness check (`E0210 undefined binding` after a
closure ends), not a redundant safety net the way `verifyTypes`' equivalent
turned out to be — so *any* copy taken to make it pushMut-safe still costs
O(current-scope-size) per occurrence, same as the bug it would replace. A
real fix needs a structurally different approach: keep the large outer
scope as an untouched reference and track only a small, per-closure "local
additions" stack, checking both on lookup, rather than one combined,
copied-on-every-nesting list. Scoped out of this pass as a bigger redesign
than warranted a rushed attempt.

**Generics**: the remaining ~3.3–3.9x doubling ratio's mechanism was not
located. `generic_calls.lume`'s control contains no closures or match
expressions, so the closures mechanism above cannot be it — something else
in generic call-site handling still scales with N, unidentified.

**Bottom line, superseding this section's own earlier claim**: there is no
single dominant floor left. Compile time in this bootstrap is the sum of
at least four identified, mostly-independent quadratic-or-worse
mechanisms — the lexer (fixed), `compileBlock`'s and `verifyTypes`' own
binding-tracking (both fixed), and at least two more (closures'
`validateExpression` mechanism, identified; generics' mechanism,
unidentified) still open. Each fix so far has been real and worth keeping,
and each has revealed that the next-largest number was riding on a
*different* mechanism than assumed - the honest state of this investigation
is that it found and fixed three real bugs across two files (one in Certo,
two in `lume.cto`), improved the common case by ~7x and closures/generics
by a further ~15-30% beyond that, and still has real, quadratic scaling
left in the two most feature-rich code paths this bootstrap has.

## Closures' remaining mechanism, fixed - and a second, bigger one found alongside it (2026-09-11)

The previous section's "real fix" sketch for `validateExpression`'s
`activeNames` bug - keep the outer scope as an untouched reference, track
only a small per-closure "local additions" stack, check both on lookup -
was implemented. `validateExpression` no longer takes raw `names`/`mutables`
lists at all; it takes the same `nameBuckets`/`mutableBuckets` hash-bucket
structures `compileBlock` already builds for its own duplicate/undefined
checks, and tracks closure-parameter and match-arm-binding names in a
small `localNames` list, truncated back to a recorded boundary (an
integer, not a snapshot) on `closure_end`/`match_arm`/`match_finish`. This
list's size is bounded by nesting depth and per-scope parameter count, not
by the enclosing function's total statement count, so both the growth
(`List.pushMut`, not `List.push`) and the truncation (`List.slice` of a
small list) stay cheap regardless of how large the function is.

Rebuilding and re-measuring a capturing-closure sweep (same
`list.map(items, fn(v) -> int => v + base)` × N shape as the original
closure-scaling section) with only this fix applied, against the
previous section's own post-`verifyTypes`-fix baseline:

| N | After lexer + `verifyTypes` fixes (previous section) | After `validateExpression` fix alone |
| ---: | ---: | ---: |
| 2,000 | 4.61 s | 3.02 s |
| 4,000 | 18.74 s | 12.83 s |

A real ~30% improvement, but the doubling ratio (12.83 / 3.02 = 4.2x)
was still unmistakably quadratic - direct instrumentation (temporary
`monotonicMillis` timers around `compileBlock` and `verifyTypes` in
`compile`, the same technique as the lexer investigation, reverted before
committing) showed why: `compileBlock` (which contains
`validateExpression`) dropped to 15 ms at N = 4,000, but `verifyTypes`
still cost 11,828 ms. **The fix was correct but wasn't the dominant cost -
`validateExpression`'s bug was real but smaller than assumed, sitting
underneath a second, larger mechanism in a completely different
function.**

**The actual dominant mechanism, located by the same instrumentation**:
`findFunction` (used throughout `verifyTypes` and its helpers to resolve a
called name to its declaration site) scans the *entire* combined
instruction list from index 0 until it finds a matching `"function"`
marker - and returns -1 only after scanning every single instruction, for
a name that will never match one. `checkCallTypes` called `findFunction`
unconditionally for every `"call"` instruction, including calls to
`list.map`/`str.len`/every other builtin, none of which have a
`"function"` marker at all - so every builtin call paid a full O(program
size) scan just to learn "not a user function", before falling through to
`checkBuiltinTypes`. Worse, `checkBuiltinTypes`'s own `list.map`/`filter`/
`find`/`fold` handling called `findFunction` *again*, unconditionally, even
when the callback was a closure (`callbackName` is `""` in that case, so
this call could never have succeeded) - a second full scan thrown away
immediately after computing it. A function with N `list.map` calls, each
triggering two wasted full-list scans of an instruction list that itself
grows with N, is exactly O(n²).

**The fix**: skip `findFunction` entirely when it cannot possibly help.
`checkCallTypes` now checks `containsName(builtinNames(), call.text)` (a
fixed ~40-entry list, O(1) relative to program size) before calling
`findFunction` at all - `validateExpression` has already rejected any call
whose name is neither a declared function nor a builtin (`E0216`), so a
builtin-list hit is guaranteed to route to `checkBuiltinTypes` either way,
just without paying the scan to reach that answer. `checkBuiltinTypes`'s
`list.map`/`filter`/`find`/`fold` handling now only calls `findFunction` in
the non-closure branch, where a named-function target is actually needed.
Calls to genuinely user-declared functions are completely unaffected -
`findFunction` still runs for them, exactly as before.

**Correctness, verified before trusting it**: full smoke suite green (same
one pre-existing, unrelated CRLF-byte failure as every other entry in this
file); `task_board` output byte-identical to the pre-session baseline; and
two new stress tests specifically targeting the scope-leak risk the
`validateExpression` rewrite depends on now live in the permanent suite
(`examples/invalid_closure_scope_leak.lume`, two sibling closures reusing
the parameter name `value`, confirming neither leaks past its own
`closure_end`; `examples/invalid_closure_match_scope_leak.lume`, a `match`
nested inside a closure, confirming the two independent boundary stacks
unwind correctly in LIFO order) - both correctly report `E0210 undefined
binding` for a reference after the relevant scope has closed.

**Performance result - the complexity class changed, not just the
constant**, confirmed with the same doubling-ratio sweep used for the
lexer fix, out to N = 32,000:

| N | Before any 2026-09-11 closure fix | After both fixes |
| ---: | ---: | ---: |
| 250 | 0.123 s | 0.024 s |
| 500 | 0.434 s | 0.027 s |
| 1,000 | 1.630 s | 0.040 s |
| 2,000 | 7.05 s | 0.071 s |
| 4,000 | 31.95 s | 0.130 s |
| 8,000 | (not measured; extrapolates to ~140 s) | 0.267 s |
| 16,000 | — | 0.633 s |
| 32,000 | — | 1.300 s |

| N doubling | Before (quadratic signature) | After |
| --- | ---: | ---: |
| 2,000 → 4,000 | ~4.5x | 1.83x |
| 4,000 → 8,000 | (extrapolated ~4x) | 2.06x |
| 8,000 → 16,000 | — | 2.37x |
| 16,000 → 32,000 | — | 2.05x |

The doubling ratio settles at ~2.0–2.4x across four consecutive doublings
from N = 4,000 to N = 32,000 - the linear signature, not the ~4x quadratic
one this same workload showed at every previous stage of this
investigation. At N = 4,000, closures went from ~104x the trivial
baseline (the original closure-scaling section) to effectively free. The
representative feature-mix benchmark (records, enums, generics, closures
mixed - the same file used throughout this document) confirms the effect
end-to-end:

| Benchmark | 2026-09-11, after lexer + `verifyTypes` fixes | After today's closure fixes |
| --- | ---: | ---: |
| `benchmark-10000-features.ps1 -Iterations 1` (mean compile) | 14,125 ms | **3,391 ms** (~4.2x faster) |
| Lines/second | ~708 | **2,949** |

Still below the benchmark's own 10,000-lines/second bar (`TargetMet:
False`), and the trivial benchmark is unaffected (51.6 ms / 193,798
lines/second this run, within normal run-to-run noise of the 44.55 ms
figure above - this workload has no closures to fix). But the
feature-mix number, which is the one workload in this file that actually
resembles a real Lume program's `main`, just got ~4.2x faster from two
fixes confined to `validateExpression` and `verifyTypes`/`checkBuiltinTypes`.

**Generics are confirmed unaffected, not accidentally fixed too** - a
targeted re-check (`identity<T>(value: T) -> T`, N calls, same doubling
sweep) after both fixes:

| N | Before (2026-09-11 generics-scaling section) | After today's fixes |
| ---: | ---: | ---: |
| 2,000 | 0.487 s | 0.345 s |
| 4,000 | 1.948 s | 1.333 s |
| 8,000 | 8.65 s | 6.14 s |

Doubling ratios (3.9x, 4.6x) are still clearly quadratic - the small
constant-factor improvement here is incidental (generic calls also lex and
parse their own bodies, same as every other workload in this file
benefited from the earlier lexer fix's residual effect), not evidence that
today's fixes touched whatever generics' own mechanism is.
`checkCallTypes`'s new builtin fast path never applies to a call to a
user-declared generic function, and `findFunction`'s successful-match scan
for `identity` (declared once, near the top of every control file in this
sweep) was already cheap before today - so this result is exactly what the
fix's own scope predicts, not a surprise.

**Bottom line**: this investigation's own two remaining, identified/
unidentified mechanisms from the previous section are down to one.
Closures' mechanism was two mechanisms, not one - the identified
`validateExpression` bug (real, fixed, but a modest ~6% contributor by
itself) and a second, unidentified-until-now, much larger one
(`findFunction`'s wasted full-list scans on every builtin call, ~2x-plus
contributor, fixed) - and fixing both together changed capturing closures'
complexity class from quadratic to linear, confirmed out to N = 32,000, the
same bar the lexer fix was held to. **Generics' mechanism remains the one
open item**: still quadratic (~3.9-4.6x per doubling), still not located,
confirmed unaffected by everything fixed today. Whatever drives it is
neither the lexer, nor `compileBlock`'s or `verifyTypes`' binding-tracking,
nor `validateExpression`'s local-scope tracking, nor `findFunction`'s
wasted scans on builtin calls - all five are now fixed or ruled out for
this specific workload, and a call to a single, early-declared generic
function still gets quadratically slower to compile as call count grows.
Finding it is the natural next step for this investigation.

## Generics' mechanism, located: a Certo `and`/`or` short-circuit bug (2026-09-11)

Every prior source-reading pass over `checkCallTypes`'s generic-call
handling (the argument loop, `inferGeneric`, `substituteType`, the
generic-completeness loop) found nothing that should scale with N - every
list involved (`genericNames`, `genericTypes`, `stack`) stays at length 1
or less for a single-type-parameter call like `identity<T>(value)`. Direct
instrumentation (the same `monotonicMillis`-timer technique used
throughout this file, reverted before committing) confirmed the cost was
still entirely inside `checkCallTypes` (5,656 of 5,672 ms of `verifyTypes`'
total at N = 8,000 - `findFunction` itself measured at a flat, non-scaling
2 steps per call, ruling it back out) but source reading alone couldn't
find where inside it.

**The isolating experiment**: cumulative cost per call, measured across
different total-program sizes, wasn't the same at each size - the average
per-call cost inside `checkCallTypes` grew with N (0.14 ms at N = 2,000,
0.30 ms at N = 4,000, 0.71 ms at N = 8,000) even though a per-batch
breakdown *within* one run stayed flat throughout (every 500-call window
in the N = 8,000 run cost ~350-390 ms, no growth from the first batch to
the last). That combination - flat within a run, scaling only *across*
differently-sized runs - pointed at something proportional to the whole
program's size, computed identically on every call, rather than something
that accumulates as the run progresses. A direct test confirmed it: 100
plain (non-generic) calls added after 7,900 unrelated padding statements
cost 0 ms, but 100 *generic* calls added after the same 7,900 lines of
padding cost 31 ms - the padding contains no calls at all, so whatever
this is, it is triggered by being a generic call specifically, and its
cost is set by how much file precedes it, not by how many calls came
before it.

**Fine-grained phase timestamps inside `checkCallTypes`'s generic branch**
narrowed it to one specific loop: the generic-constraint-completeness
check,

```
if not Text.eq(requirement, "") and not knownGenericConstraint(code, requirement) then {
  problem = "E0679 ..."
} else if not Text.eq(requirement, "") and not satisfiesGenericConstraint(code, ..., requirement) then {
  problem = "E0680 ..."
}
```

For an *unconstrained* generic like `identity<T>`, `requirement` is `""`
and `not Text.eq(requirement, "")` is `false` - this code is written on
the assumption that `and`'s left operand being `false` skips the right
operand entirely, so `knownGenericConstraint`/`satisfiesGenericConstraint`
should never run. A call counter added directly inside `hasProtocol` (the
function `knownGenericConstraint` falls through to, which does a full
`for item in code` scan of the *entire program's instruction list* looking
for a matching `protocol_type` declaration) showed it firing exactly once
per generic call anyway - 100 times for the 100-call padded file, with
`codeLen=16110` printed alongside every call, confirming each firing scans
the whole program. `hasProtocolImplementation` (reached the same way
through `satisfiesGenericConstraint`, an equally full scan of every
`protocol_impl` instruction) fired exactly as often.

**Root cause, confirmed with a minimal, standalone, isolated `.cto`
program run directly through `certo run` (independent of Lume entirely -
this is a Certo bug, not a `lume.cto` bug, same as item 325's
`Text.slice`)**:

```
fn expensive(): Bool = { println("called"); false }
fn main(): Unit = {
  val requirement = ""
  if not Text.eq(requirement, "") and not expensive() then { println("A") }
  else { println("B") }
}
```

prints `called` then `B` - `expensive()` runs even though the left operand
of `and` is `false` and fully determines the result. A broader sweep
(`false and expensiveTrue()`, `true or expensiveFalse()`, `not false and
not expensiveFalse()`, `not true and not expensiveFalse()`) confirmed this
for both `and` and `or`, with and without `not`: **every case evaluates
both operands unconditionally**, contradicting the language specification's
own operator table, which documents both `and` and `or` as
"(short-circuit)". The final boolean result was correct in every case
tested - this is a wasted-evaluation and unguarded-panic-risk bug, not a
wrong-answer bug - but it means any guard of the shape `cheapCheck() and
expensiveCall()` in Certo, including several in `lume.cto` itself, silently
never skips the expensive call. Filed as Certo BACKLOG.md item 326 for
that project to investigate the actual root cause (eager HIR/MIR lowering
of `and`/`or` instead of the conditional-branch codegen the spec's contract
requires, or something narrower - not yet determined on the Certo side).

**The fix, entirely on the `lume.cto` side**: replace reliance on `and`
short-circuiting with actual nested control flow, which - unlike `and`/
`or` - genuinely does only execute the reached branch. `checkCallTypes`'s
constraint check became `if not Text.eq(requirement, "") then { if not
knownGenericConstraint(...) then {...} else if not
satisfiesGenericConstraint(...) then {...} }`, guaranteeing both expensive
calls are skipped whenever `requirement` is empty, independent of Certo's
`and` behavior. `knownGenericConstraint` itself had the identical bug one
level in: `Text.eq(requirement, "Eq") or ... or hasProtocol(code,
requirement)` called `hasProtocol` even when an earlier clause (a built-in
marker like `"Eq"`) already matched - rewritten as an `if`/`else if` chain,
which only evaluates and runs the one branch actually reached. A third,
lower-impact instance in `verifyTypes`'s function-declaration constraint
check (`if Text.eq(problem, "") and not knownGenericConstraint(...)`,
bounded by a function's own declared-constraint count rather than N) got
the same nested-`if` treatment for consistency, though it wasn't part of
the measured quadratic cost.

**Correctness, verified before trusting it**: full smoke suite green (same
one pre-existing, unrelated CRLF-byte failure as every other entry in this
file); `task_board` output byte-identical to every prior baseline in this
file. More directly relevant here than for most fixes in this file: the
existing smoke suite already exercises every branch this change touches
end-to-end - `generic constraint validation` and `generic constraint name
validation` (E0680/E0679 for a built-in marker constraint),
`protocol implementation constraint` (E0680 for a user protocol
constraint) - all four still produce byte-identical error messages
(including line numbers) after the rewrite, confirming the nested-`if`
restructuring preserves exactly the semantics the original `and`-based
guards were written to express, just without relying on a short-circuit
contract Certo doesn't actually honor.

**Performance result - another complexity-class change, confirmed out to
N = 32,000 for the unconstrained case**:

| N | Unconstrained generic (`identity<T>`), before | after |
| ---: | ---: | ---: |
| 2,000 | 0.487 s (original) / 0.345 s (post-closure-fixes) | 0.035 s |
| 4,000 | 1.948 s / 1.333 s | 0.064 s |
| 8,000 | 8.65 s / 6.14 s | 0.118 s |
| 16,000 | — | 0.308 s |
| 32,000 | — | 0.598 s |

| N doubling | Before (quadratic, ~3.9-4.6x) | After |
| --- | ---: | ---: |
| 2,000 → 4,000 | ~3.9x | 1.83x |
| 4,000 → 8,000 | ~4.6x | 1.84x |
| 8,000 → 16,000 | — | 2.61x |
| 16,000 → 32,000 | — | 1.94x |

**Built-in-marker-constrained generics (`fn keep_number<T: Number>`)
improved by the same mechanism**, since every constrained call also went
through the now-fixed `knownGenericConstraint`/`satisfiesGenericConstraint`
path (previously paying the wasted scans on top of an actually-needed
constraint check, rather than instead of a skipped one):

| N | Constrained generic (`keep_number<T: Number>`), after |
| ---: | ---: |
| 2,000 | 0.063 s |
| 4,000 | 0.095 s |
| 8,000 | 0.150 s |
| 16,000 | 0.295 s |

Doubling ratios (1.52x, 1.58x, 1.97x) confirm the same shift to
near-linear scaling. This closes the gap the "Generics vs. protocols,
re-measured after protocol methods" section left open, where built-in-
marker-constrained and user-protocol-constrained generics had converged to
the same ~5x-baseline cost after protocol methods landed - both were
riding this same bug, just reached from different call shapes.

**End-to-end effect on the representative feature-mix benchmark** (the one
workload in this file that actually resembles a real Lume program,
combining records, enums, generics, and closures):

| Stage | Mean compile |
| --- | ---: |
| Original (no 2026-09-11 fixes) | 21,563 ms |
| After lexer + `verifyTypes` binding fixes | 14,125 ms |
| After closure fixes (`validateExpression` + `findFunction`) | 3,391 ms |
| After this generics fix | **1,719 ms** |

Still below the benchmark's own 10,000-lines/second bar (5,817 achieved),
but the gap has closed from ~69x at the start of this file's investigation
to under 2x now. The trivial benchmark is unaffected (54.7 ms this run,
within normal noise of the 44.55 ms figure recorded earlier).

**Bottom line**: this was the last of the mechanisms this investigation
had explicitly left open. Every quadratic-or-worse mechanism identified in
this file across both sessions - the lexer (Certo `Text.slice`, fixed
upstream), `compileBlock`'s and `verifyTypes`' own binding-tracking (two
`lume.cto` bugs, fixed), `validateExpression`'s local-scope tracking
(`lume.cto`, fixed), `findFunction`'s wasted scans on builtin and closure
calls (`lume.cto`, fixed), and now generic-constraint checking's wasted
scans caused by Certo's own non-short-circuiting `and`/`or`
(`lume.cto`-side workaround shipped; root cause filed upstream as item
326) - is now either fixed or ruled out. Closures went from ~104x the
trivial baseline to linear; generics went from ~5x-and-quadratic to
linear. What remains is incremental: profile whether any smaller,
non-quadratic constant-factor costs are worth chasing, and re-run the
acceptance-gate and AI-evaluation-suite checks this file has repeatedly
noted as unverified, now that the compiler they'd be measuring is in a
fundamentally different performance class than when this investigation
began.

## User-protocol-constrained generics, one more mechanism found: unindexed protocol scans (2026-09-11)

The previous section's fix made `knownGenericConstraint`/`satisfiesGenericConstraint`
stop running *wastefully* for unconstrained calls, but a call that
*genuinely* has a user-protocol constraint (`fn keep_named<T: Named>`, as
opposed to a built-in marker like `Number`) still falls through to
`hasProtocol`/`hasProtocolImplementation` - and those two functions were
never touched by that fix, since they were being called *correctly* by the
letter of the guard logic, just inefficiently. Both do a `for item in code`
scan of the *entire program's instruction list* looking for a matching
`protocol_type`/`protocol_impl` declaration - and protocol declarations are
fixed for the whole program, never changing between calls, so a function
constrained by a user protocol and called N times pays N full
O(program-size) scans for an answer that's identical every time.

A direct sweep of `fn keep_named<T: Named>(value: T) -> T` called N times
(a real record type implementing `Named` via a method, not the marker-only
model) confirmed this is exactly the same quadratic shape found and fixed
throughout this file:

| N | `lume check` wall time |
| ---: | ---: |
| 500 | 0.062 s |
| 1,000 | 0.138 s |
| 2,000 | 0.433 s |
| 4,000 | 1.892 s |
| 8,000 | 8.224 s |

| N doubling | Ratio |
| --- | ---: |
| 500 → 1,000 | 2.22x |
| 1,000 → 2,000 | 3.14x |
| 2,000 → 4,000 | 4.37x |
| 4,000 → 8,000 | 4.35x |

Converging to ~4.3x - the same quadratic signature as every other
mechanism in this file.

**The fix**: since protocol declarations/implementations never change
during `verifyTypes`' single pass, seed a fixed-bucket hash set for each -
`protocolBuckets` (protocol names) and `protocolImplBuckets`, keyed by
`"protocolName|typeName"` since one protocol can have several
implementations - **once**, in one O(program-size) pass before the main
loop, using the same `emptyBuckets`/`insertBucket`/`bucketsContains`
machinery this file has used for every other lookup-replaces-scan fix.
`hasProtocol`/`hasProtocolImplementation` become plain bucket lookups
against the pre-built sets instead of taking `code` and re-scanning it;
`knownGenericConstraint`/`satisfiesGenericConstraint`/`checkCallTypes` were
updated to thread the two bucket parameters through instead of `code`
(only used for these three functions and the one other, low-frequency
function-declaration-constraint call site - not a broad signature change
across the file). As a side effect, this also removes a latent panic risk
in the old `hasProtocolImplementation`: `List.len(parts) > 1 and
Text.eq(List.getOrPanic(parts, 0), ...) and Text.eq(List.getOrPanic(parts,
1), ...)` relied on the same broken Certo `and` short-circuiting to avoid
indexing `parts` out of bounds when a malformed entry had fewer than 2
parts - the bucket-based rewrite has no such indexing at all.

**Correctness, verified before trusting it**: full smoke suite green (same
one pre-existing CRLF failure); `task_board` byte-identical. The existing
suite already exercises every branch this touches end-to-end -
`protocol implementation constraint` (E0680 for a user protocol),
`unknown protocol implementation`, `missing protocol method`, `protocol
method signature`, `extra protocol method` - all still pass with
byte-identical messages. Added one more manual check beyond the smoke
suite: two protocols (`Named`, `Aged`) each implemented for a different
type (`Person`/`Robot`), confirming `keep_named<T: Named>(robot)` still
correctly fails with `E0680` - ruling out cross-contamination between the
`"protocolName|typeName"` bucket keys for different protocol/type
combinations.

**Performance result - another complexity-class change, confirmed to
N = 32,000**:

| N | Before | After |
| ---: | ---: | ---: |
| 500 | 0.062 s | 0.024 s |
| 1,000 | 0.138 s | 0.027 s |
| 2,000 | 0.433 s | 0.039 s |
| 4,000 | 1.892 s | 0.073 s |
| 8,000 | 8.224 s | 0.139 s |
| 16,000 | — | 0.348 s |
| 32,000 | — | 0.665 s |

N = 8,000: **~59x faster.** Doubling ratios after the fix (1.90x, 2.50x,
1.91x from N = 4,000 onward) confirm linear scaling, the same bar every
other complexity-class fix in this file has been held to.

**End-to-end effect on the representative feature-mix benchmark is the
largest single jump recorded in this entire file** - larger than the
lexer fix, larger than the closure fixes, larger than the unconstrained-
generics fix, because the feature mix's own generic function is
constrained by a user marker protocol (its own description: "a
marker-protocol constraint"), exactly the pattern this fix targets:

| Stage | Mean compile | Lines/second | `TargetMet` |
| --- | ---: | ---: | --- |
| Original (no 2026-09-11 fixes) | 21,563 ms | 464 | False |
| After lexer + `verifyTypes` binding fixes | 14,125 ms | 708 | False |
| After closure fixes | 3,391 ms | 2,949 | False |
| After the generics `and`/`or` fix | 1,719 ms | 5,817 | False |
| **After this protocol-scan fix** | **156 ms** | **64,103** | **True** |

**This is the first time in this entire investigation that the
representative feature-mix benchmark has cleared its own 10,000-
lines/second bar** - reproduced twice (156 ms both runs) before trusting
it. The trivial benchmark is unaffected (57.8 ms this run, within normal
noise).

**Bottom line**: what looked like "the generics mechanism is fixed" after
the `and`/`or` short-circuit fix was actually only the *unconstrained* and
*built-in-marker-constrained* cases. A real, common pattern - a generic
function constrained by a project's own protocol, the pattern the 0.1
milestone's own "Now" section (generic protocol-method dispatch) is
explicitly building toward - was still quadratic underneath, hidden
because `checkCallTypes` itself no longer showed as the dominant cost once
the wasted empty-constraint scans were removed, but the constraint check
still cost real O(program-size) time whenever it was genuinely needed.
Between this and the previous section, every one of `hasProtocol`,
`hasProtocolImplementation`, `knownGenericConstraint`, and
`satisfiesGenericConstraint` - the full set of functions this file's
protocol/generic-constraint machinery touches - is now backed by an O(1)-
ish bucket lookup rather than an O(program-size) scan, whether called
wastefully or legitimately.

## Confirming linear scaling holds, and one more constant-factor fix: dispatch-chain ordering (2026-09-12)

With every identified quadratic-or-worse mechanism fixed or ruled out, the
next question was direct: is the remaining gap to Certo's own raw compile
speed (measured separately - see below) still hiding an algorithmic problem,
or is it now a genuine constant-factor difference? Direct instrumentation
(the same `monotonicMillis`-timer technique used throughout this file,
reverted before committing) around `lex`, the per-function `compileBlock`
loop, and `verifyTypes`, swept across N = 5,000 / 10,000 / 20,000 / 40,000 /
80,000 / 160,000 / 320,000 lines of the trivial `total = total + 1` control:

| N | `lex` | `compileBlock` | `verifyTypes` |
| ---: | ---: | ---: | ---: |
| 160,000 | 266 ms | 328 ms | 172 ms |
| 320,000 | 547 ms | 672 ms | 360 ms |

Doubling ratios for all three land at ~1.9-2.1x from N = 160,000 to
320,000 - genuinely linear, not the ~4x quadratic signature this file has
repeatedly found and fixed elsewhere. **This confirms the remaining gap is
now a constant-factor one**: Lume's own compiler doing more work per line
than Certo's does, not a hidden complexity-class bug.

**One additional constant-factor fix found while confirming this**:
`verifyTypes`' main per-instruction dispatch is a single large `if`/`else-
if` chain checked once per instruction in the whole program. It was ordered
by feature grouping (declarations first, then expressions, then control
flow), not by frequency - `function`, `closure_start`/`end`, and `param`
were checked before `load`, `store`, `const_int`, `call`, and the
arithmetic/comparison operators, even though the latter group accounts for
the overwhelming majority of instructions in any real function body while
the former group occurs at most once per function/closure/parameter.
Every load, store, and arithmetic instruction - by far the most common
instructions that exist - was paying for several guaranteed-to-fail
`Text.eq` comparisons against rare structural ops before ever reaching its
own branch.

**The fix**: reordered the chain by measured real-world frequency -
`load`/`store`/`const_*`/`call`/arithmetic/`compare`/`return`/`jump_false`/
`print` first, structural ops (`function`/`closure_*`/`match_*`/`param`/
`decode_json`) last. This changes nothing about which branch ultimately
matches - the conditions are mutually exclusive exact-string checks on a
compiler-generated `op` field never influenced by user identifiers, so
reordering is a pure performance change, not a behavior change (confirmed:
full smoke suite unchanged, `task_board` byte-identical).

**Performance result - real but modest, exactly as expected for a
constant-factor-only fix**: at N = 320,000, `verifyTypes` dropped from
360 ms to ~330-375 ms across repeated runs (roughly 5-10%, and within
normal measurement noise at the 10,000-line scale the standard benchmarks
use - `benchmark-10000.ps1` and `benchmark-10000-features.ps1` show no
measurable change outside their existing run-to-run variance). This is not
another complexity-class fix like the rest of this file - there is no more
low-hanging complexity-class fruit left to find, by design, since this
section's own sweep just confirmed every phase is already linear. Kept
because it is a real, zero-risk improvement with no offsetting cost.

**Certo-vs-Lume compile speed, measured directly and fairly (same machine,
same process-invocation method, trivial 10,000-line program, `check`-only,
no codegen)**:

| Compiler | Mean of 10 runs |
| --- | ---: |
| `certo check` | 22.7 ms |
| `lume check` | 104.0 ms |

Certo is ~4.6x faster on this trivial workload. This is not evidence of a
remaining bug in `lume.cto` - it reflects Certo being a mature, dedicated
Rust compiler against Lume's entire compiler being a single ~4,000-line
bootstrap implementation, itself written in and run through Certo, still
working toward its own "10,000 lines in under 10 ms" design target (this
session's own trivial-benchmark result: ~53-58 ms, ~5.3-5.8x over that
target). Closing the rest of this gap would mean profiling and shaving
constant factors throughout the pipeline - lexer character-classification
cost, hash-bucket overhead, `Text`/`List` operation counts - rather than
finding more mechanisms whose complexity class is wrong, which is a
fundamentally different (and much lower-leverage, per-change) kind of work
than everything else in this file.

## Confirming generic-dispatch scaling holds after the non-`Self`-parameter extension (2026-09-12)

The last open item under the generic-dispatch milestone: a dedicated
benchmark exercising many `T.method(value)` generic-dispatch call sites,
to confirm this specific mechanism scales linearly rather than
quadratically - the same doubling-sweep discipline this file has applied
to every other mechanism, now pointed at `checkGenericProtocolCall` and
the two new passes added for non-`Self` parameters (`patchGenericDispatch`,
plus the generalized runtime dispatch branches in `execute()`/`callPure()`).

This mechanism is structurally different from the earlier "generic function
calls" sweep: type-erased generics check a function's body exactly once
regardless of how many times that function is later called, so a generic
function called N times contributes exactly one dispatch call site, not N.
Stressing dispatch at scale therefore means many *distinct* `T.method(...)`
sites, not many calls to one - the sweep generator (and the new permanent
`benchmark-10000-generic-dispatch.ps1`) puts N distinct
`T.compare(value, target)` statements directly inside one generic
function's body.

`lume check`, timed standalone, swept across N = 250 / 500 / 1,000 / 2,000
/ 4,000 / 8,000 / 16,000 distinct dispatch sites:

| N | Time |
| ---: | ---: |
| 250 | 0.038 s |
| 500 | 0.030 s |
| 1,000 | 0.043 s |
| 2,000 | 0.070 s |
| 4,000 | 0.116 s |
| 8,000 | 0.227 s |
| 16,000 | 0.428 s |

N = 8,000 was reproduced twice more (0.223 s, 0.228 s) before trusting it -
consistent within normal run-to-run noise.

| N doubling | Ratio |
| --- | ---: |
| 500 → 1,000 | 1.44x |
| 1,000 → 2,000 | 1.61x |
| 2,000 → 4,000 | 1.66x |
| 4,000 → 8,000 | 1.96x |
| 8,000 → 16,000 | 1.88x |

**Genuinely linear.** The doubling ratio holds near a flat ~1.9-2.0x
across the whole range rather than climbing toward the ~4x signature every
quadratic mechanism in this file has shown (250 → 500 alone reads below
1.0x, but that's fixed process-startup overhead dominating a sub-40ms
measurement, the same small-N noise every other sweep in this file has
also shown - not a real speedup). The user-protocol-constrained-generics
fix earlier in this file already eliminated the one identified quadratic
mechanism in this area (an unindexed, per-call protocol scan); this sweep
confirms neither that fix nor the non-`Self`-parameter work added on top
of it (`patchGenericDispatch`'s own single O(program size) pass, plus one
small O(schema size) lookup per dispatch site) reintroduced a hidden
superlinear cost. `benchmark-10000-generic-dispatch.ps1` is the permanent,
fixed-N regression guard for this mechanism going forward, mirroring
`benchmark-10000.ps1` and `benchmark-10000-features.ps1`.

## Confirming no compile-time regression from test timeouts and process-output assertions (2026-09-13)

ROADMAP.md's acceptance gate requires a before/after measurement for any
feature entering the core, so this checks the one item added in this
change: an optional `test "name", timeout: <ms> { }` clause and three new
`expect.exit_code`/`expect.stdout_contains`/`expect.stderr_contains`
builtins (see ROADMAP.md's "Stronger test tooling" section).

This feature's only compile-time-path changes are inside `scanFunctions`'
existing `test` branch and `compile()`'s existing `isTest` handling — both
already gated behind `Text.eq(at(tokens, index).text, "test")`, so a
program with zero `test` declarations (like `benchmark-10000.ps1`'s
trivial 10,000-line file) cannot execute the new code at all. The
enforcement mechanism itself (a deadline check inside `callPure`'s
dispatch loop) is a *runtime* cost, not a compile-time one, and is itself
gated behind `deadlineMs > 0` — inactive for every program that isn't
`lume test` running a test with a `timeout:` clause. No new benchmark
sweep was needed for the runtime side for the same reason the roadmap's
own compile-time gate doesn't apply to it: `execute()`, the interpreter
for ordinary `lume run`/`lume check`, never calls `callPure` at all except
indirectly through `callBuiltin` for `list.*`/`map.*` callbacks, and even
then with `deadlineMs` fixed at `0`.

Built two binaries from the same machine: `01bafed` (immediately before
this change) as baseline, and this change's own commit as current, both
via the standard `certo release` build `build.ps1` uses. `benchmark-10000.ps1`
(trivial 10,000-line file, no `test` declarations, 20 iterations, `lume
benchmark`'s in-process compile loop) three times per binary:

| Run | Baseline lines/s | Current lines/s |
| --- | ---: | ---: |
| 1 | 152,439 | 154,202 |
| 2 | 152,439 | 152,439 |
| 3 | 152,439 | 156,128 |

Baseline is perfectly stable across all three runs (identical to the
millisecond); current varies 152,439-156,128 - i.e. sometimes *faster*
than baseline - which is ordinary run-to-run system noise, not a
regression signal in either direction. `benchmark-10000-features.ps1`
(the representative feature-mix file) shows the same picture at its own
single-iteration granularity: `CompileTotalMs=172` for both baseline and
current, byte-for-byte identical.

**No compile-time regression.** Both the trivial and feature-mix
benchmarks clear their targets by the same wide margin as before this
change (`TargetMet: True`, ~15x over the 10,000-lines/second bootstrap
target), consistent with the architectural read above that this feature's
compile-time footprint is zero for any program that doesn't declare a
`test "name", timeout: ...` clause.

## Fixing `lume benchmark`'s out-of-memory crash on the feature-mix workload (2026-09-13)

ROADMAP.md's status report flagged the multi-iteration harness itself as
broken: `lume benchmark <path> 20` - the in-process command every script in
this file except `benchmark.ps1` delegates its iteration loop to - crashes
with `certo panic: out of memory` on `benchmark-10000-features.ps1`'s
feature-rich file, well before 20 iterations. `benchmark-10000.ps1`'s
trivial `total = total + 1` file never showed this because its per-compile
memory footprint is much smaller, not because the underlying issue doesn't
apply to it too.

**Root cause, confirmed by reading Certo's own runtime**: Certo has no
garbage collector, reference counting, or exposed manual-free primitive.
`Certo/crates/stdlib/src/collections.rs`'s `list_alloc` mallocs and panics
`"out of memory"` on failure (the literal source of the crash text), and
`certo_list_push` allocates a new backing array and copies into it but
never frees the old one - every Token/Instruction/string a compile pass
allocates is retained until the OS reclaims the whole process. `lume
benchmark`'s loop (`src/lume.cto:5451-5474`) calls `compileSource`
`iterations` times in one process and has no way to drop the previous
iteration's result. Measured directly: peak working set on the feature-mix
file grows linearly at ~110-140 MB per iteration with no plateau (2
iterations -> 282 MB, 20 -> 2.40 GB, 200 -> 22.36 GB) - this machine's 32 GB
was enough to survive 200 iterations without tripping the panic, but the
unbounded per-iteration growth is the same defect the ROADMAP crash report
describes, just requiring a smaller/busier machine (or a longer run) to
actually exhaust memory. **This is inherent to Certo, not fixable inside
`lume.cto` alone** - out of scope for a Lume-only change, the same category
as the `process.run` timeout limitation this repo already accepts.

**The fix is a benchmarking-methodology change**, already established
elsewhere in this file: `benchmark.ps1`'s `Measure-Runs` helper spawns a
fresh `lume.exe` process per timed sample rather than looping inside one
process, so the OS reclaims memory between samples and the leak never
accumulates. `benchmark-10000-features.ps1` now does the same - `lume
check $path` timed individually with a `Stopwatch` per sample, `-Iterations`
raised from `1` back to `30` (this file's own "at least 30 runs" contract,
safe now that the OOM risk is gone) - reporting `MedianMs`/`P95Ms`/
`StdDevMs` in addition to the mean for the first time on this benchmark:

| Metric | Value |
| --- | ---: |
| Iterations | 30 |
| CompileMeanMs | 267.171 |
| MedianMs | 266.428 |
| P95Ms | 279.488 |
| StdDevMs | 6.265 |
| CompileLinesPerSecond | 37,429 |

No crash across 30 fresh-process samples, tight distribution (p95 within
~5% of the median, stddev ~2.3% of the mean - a quiet machine, not a
bimodal or long-tailed one), `TargetMet: True` at ~3.7x the 10,000-line/s
bootstrap target. The absolute lines/second figure (37,429) is lower than
the previous in-process single-sample number (58,140, `CompileTotalMs=172`
for one iteration) because it now includes full process startup overhead
per sample, which the in-process measurement excluded entirely - expected,
and arguably more representative of real non-daemon CLI usage per this
file's own "exclude process startup only in a separately labelled
persistent-daemon test" contract, which the old approach violated by
excluding it unconditionally rather than in a labelled daemon-mode test.
`benchmark-10000.ps1` and `benchmark-10000-generic-dispatch.ps1` are
unchanged and still pass at their existing iteration counts (156,128 and
69,565 lines/second respectively) - they were never the ones crashing, and
this fix intentionally left them alone rather than introducing unrelated
risk into scripts that already work. The underlying `lume benchmark`
in-process command itself is unchanged and still unsafe for many
iterations on large/realistic workloads - any future large-program
benchmark script should follow `benchmark-10000-features.ps1`'s
fresh-process pattern rather than `benchmark-10000.ps1`'s in-process one.
