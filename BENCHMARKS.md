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
