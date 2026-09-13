# Lume roadmap

Lume is a focused, statically checked alternative to shell and Python for
automation, data transformation, command orchestration, configuration, and
small tools. Its priorities are fast compilation, predictable programs, and
reliable AI generation.

This roadmap distinguishes implemented behavior from proposed work. The
machine-readable source of truth for the currently supported language and
built-ins is [`ai/lume-api.json`](ai/lume-api.json). Syntax and design intent
live in [`SPEC.md`](SPEC.md), while performance requirements live in
[`BENCHMARKS.md`](BENCHMARKS.md).

## Product principles

Every addition should preserve these properties:

- static checking without global type inference;
- one clear, formatter-enforced way to express common operations;
- deterministic diagnostics suitable for people and tools;
- direct bytecode generation without a retained whole-program AST;
- no implicit conversions, truthiness, exceptions, or dynamic dispatch;
- compile time and memory that scale linearly with source size;
- a language and standard API small enough to fit in an AI prompt.

## Performance gates

The long-term design target is to compile 10,000 lines in under 10 ms in a warm
compiler process. The current bootstrap target is at least 10,000 lines per
second on the development machine.

A feature cannot enter the core if it causes either:

- more than a 5% regression in median clean compile time; or
- more than a 3% regression in AI tokens-to-correctness;

unless its improvement in task success clearly offsets that cost. Compiler
benchmarks must report median and p95 results. Language features should also be
added to the fixed AI evaluation suite.

## Status report (2026-09-11, updated same day after the protocol-scan fix)

A direct check of where the bootstrap stands against the gates and the 0.1
milestone above, based on the measurements in
[`BENCHMARKS.md`](BENCHMARKS.md) rather than on what any single feature's
own commit claimed. Read this alongside that file's dated sections, which
this summarizes without repeating. This section was first written before
the fixes below existed; it has been updated in place rather than left
stale, since an inaccurate status report defeats its own purpose.

**Performance gates: met for the trivial case and, for the first time in
this investigation, for the representative feature-mix benchmark too —
seven real bugs have been found and fixed (two in Certo, five in
`lume.cto`), and every quadratic-or-worse mechanism this investigation
identified across three sessions is now either fixed or ruled out.
Closures, generics, and user-protocol-constrained generics all changed
compile-time complexity class from quadratic to linear.**

- **What changed**: instrumenting the compiler directly (not inferring from
  black-box timing) located the dominant cost to the lexer itself, traced
  to a genuine bug in Certo's own `Text.slice` (unconditional `strlen` on
  the full source string per call, filed and fixed same-day as Certo
  BACKLOG.md item 325) plus two further, structurally similar bugs in
  `lume.cto` itself (`compileBlock`'s and `verifyTypes`' own separate
  binding-tracking, both O(n)-scan-plus-O(n)-copy where O(1)-amortized
  alternatives existed). All three are fixed, verified correct (full smoke
  suite, `task_board` byte-identical output, and targeted stress tests for
  each fix's specific correctness risk), and merged.
- **Result for representative code paths**: the trivial 10,000-line
  benchmark went from 310.95 ms to **44.55 ms (~7.0x)** — now only ~4.5x
  over the long-term 10 ms target, down from ~31x — and its
  lines/second figure (224,467) now clears the softer "current bootstrap
  target" (≥10,000 lines/second) by ~22x, not the previous ~3.2x. More
  importantly, the *complexity class* changed for this code path: a
  `print(1)` × N control's doubling ratio dropped from ~4.0x (quadratic) to
  ~1.55–1.9x (near-linear, confirmed out to N = 32,000) — this is
  convergence toward the target from a specific, located fix, contradicting
  this section's own earlier claim that the gap "does not converge... with
  more optimization of any one feature."
- **Result for the representative feature-mix benchmark (records, enums,
  generics, closures mixed)**: after the lexer and `verifyTypes` fixes
  alone it was only ~35% faster than the original baseline (21,563 ms →
  14,125 ms) — because its dominant cost was never the lexer. Closures
  turned out to ride *two* independent quadratic mechanisms, both now
  fixed: `validateExpression`'s own `activeNames` tracking (a fourth
  instance of the earlier scan/copy pattern, fixed with a structurally
  different per-closure "local additions" stack rather than the
  copy-once-then-`pushMut` trick that worked for the other three, since its
  save/restore is a genuine scope-leak correctness check (`E0210`) and not
  a redundant safety net) and, the larger of the two, `findFunction`'s
  unconditional full-instruction-list scan on every builtin call
  (`list.map`/`filter`/`find`/`fold` included) even though a builtin can
  never have the `"function"` marker that scan is looking for. Fixing both
  took the feature-mix benchmark to 3,391 ms — a further ~4.2x on top of
  the lexer/`verifyTypes` result — and changed capturing closures'
  complexity class from quadratic to linear (doubling ratio ~4.3x → ~2.0–2.4x,
  confirmed out to N = 32,000, the same bar the lexer fix was held to).
- **Generics' remaining mechanism, the one item left open, is now also
  found and fixed — and it turned out to be a genuine Certo interpreter
  bug, not a `lume.cto` algorithm problem**: Certo's `and`/`or` operators do
  not short-circuit, despite the language specification explicitly
  documenting both as "(short-circuit)" — confirmed with a minimal,
  standalone `.cto` program run independently of Lume, showing the right
  operand of `and`/`or` always evaluates regardless of the left operand.
  `checkCallTypes`'s generic-constraint check (`if not Text.eq(requirement,
  "") and not knownGenericConstraint(...) then {...}`) was written assuming
  the left operand being false would skip the expensive right-hand call —
  instead, `knownGenericConstraint` (and the full-program-instruction-list
  scan inside it) ran on *every* generic call regardless of whether it even
  had a constraint, making an unconstrained generic function called N times
  pay two wasted O(program-size) scans per call. Restructured as nested
  `if` statements, which — unlike `and`/`or` — are genuine control flow and
  only execute the branch actually reached; filed as Certo BACKLOG.md item
  326 for the Certo team to find the real root cause. Took an unconstrained
  generic call from 6.14 s to **0.118 s at N = 8,000 (~52x)**, changing its
  complexity class from quadratic (~3.9–4.6x per doubling) to linear
  (~1.8–2.6x, confirmed to N = 32,000) — and took the feature-mix benchmark
  from 3,391 ms to 1,719 ms, closing the gap from this file's original
  ~69x finding to under 2x against the benchmark's own bar.
- **One more mechanism remained, and it turned out to be the biggest single
  fix in this whole investigation**: the previous fix only stopped
  `knownGenericConstraint`/`satisfiesGenericConstraint` from running
  *wastefully*; a call that genuinely has a user-protocol constraint (as
  opposed to a built-in marker) still fell through to
  `hasProtocol`/`hasProtocolImplementation`, and both do a full
  `for item in code` scan of the *entire program's instruction list* on
  every call, looking for a `protocol_type`/`protocol_impl` declaration
  that is fixed for the whole program and never changes between calls. A
  function constrained by a real user protocol (`fn keep_named<T: Named>`)
  called N times was still quadratic (~4.35x per doubling, 8.22 s at
  N = 8,000). Fixed by seeding two fixed-bucket hash sets
  (`protocolBuckets`, `protocolImplBuckets`) once, in one O(program-size)
  pass before `verifyTypes`' main loop, replacing the two scanning
  functions with plain bucket lookups — the same technique this file has
  used for every prior scan-to-lookup fix. Took the same workload to
  0.139 s at N = 8,000 (**~59x**), linear scaling confirmed to N = 32,000
  (doubling ratios 1.90x/2.50x/1.91x). Because the representative
  feature-mix benchmark's own generic function uses exactly this pattern —
  a marker-*protocol* constraint, not a built-in one — this fix alone took
  it from 1,719 ms to **156 ms, clearing its own 10,000-lines/second bar
  for the first time in this investigation's history** (64,103
  lines/second, `TargetMet: True`, reproduced twice before trusting it).
- The acceptance gate ("no feature enters the core with more than a 5%
  compile-time regression") does not appear to have been checked against a
  measurement for every feature that has shipped. The protocol-methods
  change roughly doubled the cost of built-in-constrained generics (~2.4x
  → ~5.3x baseline); no before/after benchmark for that change is on record
  in `BENCHMARKS.md`. This gate's own machinery used to be unreliable at
  the sizes it would need to check — `lume benchmark <path> 20`, the
  in-process multi-iteration harness, crashed with `certo panic: out of
  memory` on realistic-sized input — but the benchmark *script* that
  surfaced this (`benchmark-10000-features.ps1`) has since moved off that
  in-process loop entirely onto fresh-process-per-sample timing (see the
  0.1 milestone note below and BENCHMARKS.md), so this gate can now be
  checked at 30 samples on the representative feature-mix workload; the
  underlying `lume benchmark` command itself is still unsafe for many
  in-process iterations on large input.
- **Closed**: the AI evaluation suite this file's own gate depends on
  (`ai/tasks.json`, "added to the fixed AI evaluation suite") had 7 tasks;
  `BENCHMARKS.md` specifies "at least 100." Expanded to exactly 100,
  spanning arithmetic, strings, control flow (including composing
  conditions without `and`/`or`/`not`, which Lume's grammar has no operator
  for — nested `if` and predicate functions instead, per `SPEC.md` §7),
  functions and recursion, lists (including closures passed to
  `list.map`/`filter`/`find`/`fold`), records (construction, nesting,
  `with`-update), enums and exhaustive `match` (including generic and
  multi-field variants), generics (unconstrained, `Number`/`Text`-
  constrained, generic records and enums), user protocols (declaration,
  implementation, static dispatch, generic constraint), `Option`/`Result`
  (both the full `Result<T,E>` shape and the `T ! E` shorthand), JSON
  (`json.valid`/`get` and typed `Type.from_json` decoding), and files/
  processes/environment/args. Every task was written from its own prompt
  and verified end-to-end (`lume check` + `lume run`, output compared
  byte-for-byte) before being added — one task's first draft used `++`
  instead of Lume's `+` for string concatenation, and several used
  `and`/`or`/`not`/`else if` before `SPEC.md` §7's "no boolean operators,
  no else-if chaining" constraint was found and every affected task
  rewritten around it. Final result: 100/100 compile, 100/100 correct via
  the real `ai-eval.ps1` harness. This only closes the suite-*size* gate;
  it does not by itself validate any given AI model's actual generation
  quality against it, since these reference solutions were written with
  the language's own documentation in hand rather than blind.

**0.1 "Coherent bootstrap" milestone: partially met, one item actively
false.**

- *Reconcile the specification, guide, examples, and API manifest* —
  in progress rather than done. `SPEC.md` was reconciled against the
  compiler once and has already needed follow-up correction as other work
  landed underneath it; that is expected of a document tracking a moving
  target, but it means "reconciled" is not yet a stable, closed state.
- *Finish generic protocol-method dispatch* — complete. Single- and
  multi-constraint dispatch to protocol methods of any shape (any number
  of parameters, exactly one typed `Self`) has shipped, with a dedicated
  benchmark confirming linear scaling (see "Shipped in the bootstrap"
  above). (This bullet used to cite a benchmark finding — "a generic
  function constrained by a user protocol gets no compile-time benefit
  over an unconstrained one" — as evidence the feature was entirely
  missing; that finding was
  about *compile-time cost*, not the presence of this feature, and it no
  longer holds in either direction after this file's own performance fixes
  — see the "protocol-scan fix" section.)
- *Stabilize diagnostics and bytecode serialization* — partially assessed,
  two issues found and fixed, two more scoped for later. Fixed: (1)
  `execute()`'s bytecode-dispatch loop had no catch-all for an
  unrecognized opcode — a structurally-valid but semantically-stale
  `.lbc` artifact (e.g. built by an incompatible `lume.exe`) silently
  skipped the unknown instruction instead of erroring, corrupting the
  stack; now rejected cleanly with `E0725`, mirroring the catch-all
  `callPure()` already had. (2) dead code (`scanProtocols`/
  `ProtocolScan`, an earlier marker-only protocol design fully superseded
  by `scanFunctions`' live protocol-method dispatch) retained two
  diagnostic codes (`E0253`, `E0257`) whose meanings diverged from the
  live code's own reuse of those same numbers — deleted, removing the
  collision at its root. Still open: ~125 of 217 diagnostic codes (every
  parser-level error routed through `expressionError`) carry no source
  line number at all, silently reporting `line: 0` in `--json` output —
  contradicts SPEC.md §18's "every diagnostic has a stable code, primary
  span" claim, and is independently documented in BACKLOG.md; and SPEC.md
  §17 describes an aspirational register-VM bytecode design that doesn't
  match the actual stack-based VM, missing from §19's own gap list. Both
  are large enough (many call sites; a full spec rewrite) to warrant their
  own separate pass rather than folding into this one.
- ~~Keep the complete smoke, test-runner, LSP, benchmark, and AI suites
  green~~ — the benchmark suite's crash is fixed (see BENCHMARKS.md's
  "Fixing `lume benchmark`'s out-of-memory crash" section): the in-process
  `lume benchmark <path> 20` command itself still reliably OOMs on a
  realistic-sized program well before 20 iterations — confirmed root
  cause, Certo has no garbage collector or exposed free primitive, so a
  long-running process retains every value a compile pass allocates for
  its whole lifetime, out of scope for a Lume-only fix — but
  `benchmark-10000-features.ps1` (the script that surfaced this) no longer
  depends on that command's internal loop at all: it now times 30
  independent fresh `lume.exe` processes instead, the same pattern
  `benchmark.ps1` already used, sidestepping the leak entirely and
  reporting median/p95/stddev for the first time on this benchmark
  (`TargetMet: True`, ~3.7x the 10,000-lines/second target). Any future
  benchmark script for a large/realistic program should follow that
  fresh-process pattern rather than asking `lume benchmark` to loop
  in-process, since the underlying Certo limitation is unchanged.

**What is working:** the feature surface itself is broad and functionally
correct — records, enums with payload variants, generics, generic
constraints, marker protocols, closures, `Option`/`Result`, and the native
test runner all behave as documented once `SPEC.md` was corrected to match
reality. Record and enum construction stay cheap (within ~3x of baseline)
at every size tested. And as of this update, the compile-speed gap is
closed rather than merely narrowed: seven concrete root causes have been
found (two in Certo — `Text.slice`'s unconditional `strlen`, and `and`/`or`
silently not short-circuiting despite the spec documenting both as
short-circuit — five in `lume.cto`), fixed, and verified. Every mechanism
this investigation set out to find has now been found: the trivial case is
~7x faster and linear instead of quadratic; closures went from the single
most expensive construct measured (~104x the trivial baseline) to linear;
generics — both unconstrained and constrained, by a built-in marker or a
user's own protocol — went from quadratic to linear, the protocol case
requiring both a Certo-side workaround and a `lume.cto`-side scan-to-lookup
fix. **The representative feature-mix benchmark, the one workload in this
file that actually resembles a real Lume program, went from ~69x over its
own 10,000-lines/second target at the start of this investigation to
clearing that target outright (64,103 lines/second) — the first time any
non-trivial benchmark in this file has met its own bar.**

## Shipped in the bootstrap

### Core language

- bindings, mutable variables, functions, recursion, and static types;
- `if`/`else`, `while`, and exhaustive `match` expressions;
- homogeneous lists and statically checked list operations;
- structured errors and concise result propagation with `?`;
- function values, expression-bodied closures, and immutable captures;
- modules and imports;
- register bytecode execution and a content-addressed bytecode cache.

### Typed data

- records, nested records, field access, and record update/copy syntax;
- typed JSON decoding into records, and `json.encode(value)` for the
  reverse direction — schema-free (every value already carries its own
  runtime type tag), supporting `str`/`int`/`bool`/records/lists
  recursively, plus enum values (including `Option<T>`/`Result<T,E>`,
  enums under the hood): a variant encodes as its name under a `"variant"`
  key with any payload fields flattened alongside it. One-directional —
  decoding a JSON payload into an enum field is still not supported,
  symmetric with decoding's own existing enum-field limitation;
- enums, variant construction, and statically checked variant payloads;
- exhaustive matching, duplicate-arm validation, and payload destructuring;
- built-in `Option<T>` and `Result<T, E>`.

### Generics and protocols

- generic functions, records, and enums with type substitution;
- type-erased generics without monomorphization;
- built-in and named generic constraints;
- generic list functions: `map`, `filter`, `find`, and `fold`;
- protocol declarations and explicit implementations;
- protocol methods compiled as concrete functions with static dispatch;
- a function constrained by `T: Protocol` — one constraint, or several
  joined with `+` (`T: Eq + Named`) — may call any of those protocols'
  methods on `T` from inside its own body (`T.method(value)`), resolved by
  a direct runtime type-tag check against every known implementer, not a
  vtable or an indirect dispatch table — the same closed-world mechanism
  `match` already uses for enum variants. Exactly one constraint in the
  list may declare the called method — an "ambiguous call" diagnostic fires
  if more than one does, naming every protocol that matched. The called
  method may take any number of parameters as long as exactly one is typed
  `Self` (at any position) — e.g. `fn compare(value: Self, other: int) ->
  bool`, called as `T.compare(value, 5)`. Which argument position is `Self`
  is resolved once, right after type-checking succeeds, and packed into the
  instruction so the runtime can locate the receiver among several
  arguments without disturbing the rest — a zero- or multiple-`Self`
  method still gets a clear "not yet supported" diagnostic (E0691) rather
  than an attempt to guess. A dedicated benchmark
  (`benchmark-10000-generic-dispatch.ps1`) exercises many distinct dispatch
  call sites and a doubling-size sweep confirmed this mechanism scales
  linearly, not quadratically — see BENCHMARKS.md;
- no trait objects or an indirect dispatch table for calls whose receiver
  type is statically known — those still compile straight to a concrete
  function name with zero runtime branching, exactly as before.
- `Eq` is extensible to any record or enum type via the same explicit
  `impl Eq for MyType {}` mechanism user-declared marker protocols
  already use (e.g. `impl Named for User {}`) — not automatic/derived
  conformance, which is a listed non-goal of the core language (see
  "Non-goals for the core language" below). This required no new
  validation: `==`/`!=` already compare any two values of the same
  declared type structurally, so the `impl` just lets the *constraint
  system* recognize what the operator already allowed. `Ord` stays
  restricted to `int`/`str` — `impl Ord for ...` is deliberately not
  accepted, since ordered comparison's runtime implementation only
  handles `int` today and would silently misbehave (not cleanly error)
  on any other type if the constraint let it through.

### Collections

- a built-in `Map<K, V>` — construction, lookup, and the iterator-style
  transforms `map.map`/`filter`/`fold`
  (`map.new/len/get/set/has/remove/keys/values/map/filter/fold`),
  architecturally closer to `List<T>` (its own runtime value tag, no
  schema) than to the enum-backed `Option`/`Result`; no map literal
  syntax, construction is via `map.new()` only. Key type is restricted to
  `int`/`str`/`bool` — the same set the built-in `Eq` constraint already
  recognizes — deferred extension to records/lists/enums is a separate,
  later item alongside the general "equality and ordering through
  constraints" work. `map.map`/`filter`/`fold` mirror the `list.*`
  transforms exactly, except the callback takes the value only
  (`(V) -> ...`) — keys pass through unchanged for `map.map`/`filter`; a
  `(key, value)` two-parameter callback shape is a separate, later item.

### Scripting and tooling

- filesystem, environment, argument, string, JSON, list, result, and process
  APIs;
- portable path manipulation (`path.join/basename/dirname/extension/
  stem`) — pure string operations, no filesystem access, wrapping Certo's
  own `Path.*` primitives rather than reimplementing separator handling;
  `path.stem` deliberately does not delegate to Certo's own `Path.stem`
  (which, despite its name, keeps the directory component rather than
  returning just the basename minus extension) — it's composed instead
  from `Path.basename` + `Path.extension`, matching the file-stem
  convention every other language uses;
- single-level directory enumeration (`dir.list(path) -> Result<[str],
  str>`) — entry names only, unsorted (matching this file's own existing
  `listDir` call site, which was never sorted either); recursive
  traversal remains deferred (see "Now" above) since no `isDirectory`
  primitive exists in Certo's stdlib to build one safely on top of;
- typed time (`time.now() -> int`, `time.to_iso(seconds) -> str`,
  `time.year`/`month`/`day`/`hour`/`minute`/`second(seconds) -> int` for
  UTC calendar components, `time.format(seconds, pattern) -> str` for
  `strftime`-style custom formatting, `time.in_timezone(seconds,
  zone)`/`time.format_in_timezone(seconds, pattern, zone) ->
  Result<str, str>` for IANA-zone-aware output, and
  `duration.seconds`/`minutes`/`hours`/`days(n) -> int` for named-unit
  offsets) — still a slice of Certo's much larger
  `DateTime`/`Duration`/`Timezone`/`Date` stdlib API; a distinct
  `Duration` type with its own arithmetic remains deferred (see "Now"
  above) — `duration.*` are plain functions returning `int`, not a new
  value kind;
- process exit-code, standard-output, and standard-error inspection;
- process configuration for stdin and environment overrides
  (`process.run_with_input(exe, args, input)`, `process.run_with_env(exe,
  args, envMap)`) — both return the same `process` result as
  `process.run`; environment overrides are restored to their prior value
  after the call returns; working directory and timeout remain deferred
  (see "Now" above) since no output-capturing Certo primitive accepts
  either;
- `http.get`/`http.post`/`http.put`/`http.delete(url[, body,
  content_type]) -> Result<http, str>` and `http.request(method, url,
  headers: Map<str,str>, body) -> Result<http, str>` for arbitrary
  methods and headers, with `http.status/body/content_type/ok(response)`
  accessors — a hard 10 MiB response-size cap is enforced after the
  (already-complete) download, since Certo's HTTP client has no
  streaming or early-abort mode; Windows only, since Certo's
  non-Windows `Http.*` calls are stubs that abort the process rather
  than returning an error;
- a `bytes` type, distinct from `str` at the type-checker level but
  represented identically at runtime — a deliberate scope reduction,
  since Lume's entire value representation is a single tagged `Text`
  per value (confirmed by how closures store captured variables) and a
  genuinely NUL-safe binary type would need a change to that
  representation itself. `bytes.from_str(text) -> bytes`,
  `bytes.to_str(data) -> str`, and `bytes.length(data) -> int` convert
  and inspect; `fs.read_bytes(path) -> Result<bytes, str>` and
  `fs.write_bytes(path, data) -> bool` mirror the `str` file APIs;
  `http.request_bytes(method, url, headers, data) -> Result<http, str>`
  and `http.body_bytes(response) -> bytes` mirror `http.request`/
  `http.body` with a `bytes` body. Content with an embedded NUL byte
  truncates at the NUL on round-trip — the same limitation Certo's own
  `Bytes.toText` conversion already documents, not silently different;
- human-readable and structured compiler errors;
- native test declarations, assertions, filters, and direct-child
  `*_test.lume` discovery;
- temporary-directory and environment fixtures for tests
  (`fixture.temp_dir() -> str`, `fixture.cleanup(path) -> bool`,
  `env.set(name, value) -> bool`, `env.unset(name) -> bool`) — no
  automatic cleanup, consistent with every other resource in Lume
  (files, processes) already requiring an explicit call to release;
- structured, machine-readable test output: `lume test <path> --json`
  emits JSON Lines (a `file` event per discovered test file in
  directory mode, a `test` event per result, a final `summary` event)
  instead of plain text, mirroring the `--json` convention `check`/`fmt`
  already had; combinable with `--filter` in either order;
- stable per-test identifiers (`<path>#<name>`) reported on every
  `--json` test result and matched against by `--filter` — a strict
  superset of matching by bare name, so a path fragment disambiguates
  same-named tests across files and an `id` captured from one run
  reruns exactly one test;
- an optional per-test timeout, `test "name", timeout: <milliseconds> {
  ... }` — enforced in-process by `callPure`'s own interpreter loop
  against a shared wall-clock deadline (also threaded through
  `callBuiltin` for `list.*`/`map.*` callbacks invoked from a test body),
  checked every 4096 *executed* instructions rather than against the raw
  instruction pointer, since a tight loop (`while true {}`) revisits a
  small fixed range of addresses and may never land on a naive
  address-based check interval. A timed-out test fails with `test timed
  out after <n>ms`, reported through the same path as any other
  assertion failure; a test with no `timeout:` clause is unbounded,
  unchanged from before. This bounds a hang in test *code*, not a
  subprocess — `process.run` itself still has no timeout (see "Standard
  scripting APIs" below);
- process-output assertions — `expect.exit_code(process, code: int) ->
  bool`, `expect.stdout_contains(process, text: str) -> bool`, and
  `expect.stderr_contains(process, text: str) -> bool` — for asserting
  on a `process.run`/`process.run_with_input`/`process.run_with_env`
  result inside a test, following the same `expect.*` conventions
  (`test_expect`-wrapped, `"x:<message>"` failure sentinel) as
  `expect.equal` and friends;
- local packages: a `lume.json` manifest (`name`, `version`,
  `dependencies` as an array of `{name, path}`), `lume install <dir>`
  resolving the full transitive dependency tree once into a single flat
  generated `lume.lock.json` (a dependency's own `dependencies` are
  resolved too, recursively, with cycle detection — `E0709` — and
  ambiguous-name detection — `E0708` — mirroring how `use` cycles are
  already caught), and `use` resolution reading only that lock file at
  compile time — never a manifest, never doing resolution work itself.
  A project with neither file behaves identically to before this
  existed. No registry, no semver ranges, no content-hash caching yet
  — see "2. Packages and dependency resolution" below for what's still
  open and why;
- formatter and format checking;
- language-server support;
- a machine-readable API manifest, compact AI generation contract, and fixed
  AI evaluation tasks.

## Now: production scripting foundation

Full-shape generic protocol dispatch is complete (see "Shipped in the
bootstrap" above): a function constrained by `T: Protocol` or `T: A + B +
...` can call any of those protocols' methods on `T` (any shape with
exactly one `Self` parameter), resolved at runtime by a direct type-tag
check, with precise diagnostics for every failure mode found while
building it, and a dedicated benchmark confirming the mechanism scales
linearly. That milestone is closed; this one — production scripting
foundation — is next.

### 1. Complete collections

- ~~add a typed `Map<K, V>` with a deliberately small API~~ — shipped (see
  "Shipped in the bootstrap" above);
- ~~add canonical iterator-style map transforms (`map.map`/`filter`/
  `fold`), mirroring the existing `list.*` transforms~~ — shipped (see
  "Shipped in the bootstrap" above);
- ~~define equality support through constraints, extending `Map<K, V>`'s
  key type beyond `int`/`str`/`bool`~~ — shipped for `Eq` via explicit
  `impl Eq for MyType {}` (see "Shipped in the bootstrap" above); `Ord`
  for compound types remains deferred pending a real per-type comparison
  implementation, not just a marker-based opt-in;
- keep collection operations deterministic and easy for AI to select.

### 2. Packages and dependency resolution

- ~~define a minimal package manifest and lock file~~ — shipped: a
  `lume.json` manifest (`name`, `version`, a `dependencies` array of
  `{name, path}`) and a generated `lume.lock.json` (see "Shipped in
  the bootstrap" above);
- ~~support local packages before a public registry~~ — shipped: a
  dependency is declared by a local relative path; no registry, no
  remote fetching;
- ~~separate dependency resolution from source compilation~~ —
  shipped: `lume install <dir>` does all resolution work once,
  writing the lock file; ordinary `run`/`check`/`test` only ever read
  the already-resolved lock file, never the manifest, satisfying this
  file's own closing constraint below;
- use explicit versions and deterministic resolution — partially
  shipped: `version` is declared and recorded, and resolution is
  already fully deterministic for local-path dependencies (a path has
  no ambiguity to resolve); real semver-range resolution (multiple
  candidate versions, picking one that satisfies every constraint)
  remains deferred until a registry makes that ambiguity possible in
  the first place;
- ~~resolve transitive dependencies~~ — shipped: `lume install` walks
  a dependency's own `dependencies` too, recursively, into the same
  flat `lume.lock.json`, with cycle (`E0709`) and ambiguous-name
  (`E0708`) detection mirroring `use`'s own cycle detection;
- cache resolved dependencies by content hash — deferred: not
  meaningful yet for local paths (reading a local directory has no
  fetch cost to cache); revisit once packages can come from anywhere
  other than the local filesystem.

Package management must not introduce source-level package graph resolution
into every compilation.

### 3. Stronger test tooling

- recursively discover test files with explicit ignore rules — deferred:
  blocked on the same missing `isDirectory`/`stat` primitive as `dir.list`'s
  own recursive traversal (see "4. Standard scripting APIs" below);
- ~~provide temporary-directory and environment fixtures~~ — shipped as
  `fixture.temp_dir()`/`fixture.cleanup(path)` and `env.set`/`env.unset`
  (see "Shipped in the bootstrap" above); no automatic cleanup, matching
  every other resource in Lume;
- ~~add structured test output for CI and editor integrations~~ —
  shipped as `lume test`'s `--json` flag (see "Shipped in the
  bootstrap" above), JSON Lines events for discovered files, per-test
  results, and a final summary; combinable with `--filter` in either
  order; plain-text output unchanged when `--json` is absent;
- ~~support test timeouts and process-output assertions~~ — shipped: an
  optional `, timeout: <ms>` clause on `test "name"` bounds an in-process
  test body against an infinite loop, enforced by the interpreter (a
  shared wall-clock deadline threaded through `callPure`/`callBuiltin`
  recursion, checked every 4096 executed instructions rather than by
  raw instruction address, since a tight loop can revisit a small fixed
  address range indefinitely); `expect.exit_code`/`expect.stdout_contains`/
  `expect.stderr_contains` assert on a `process.run` result (see "Shipped
  in the bootstrap" above). Deliberately does not add a timeout parameter
  to `process.run` itself — killing a hung subprocess needs new C-level
  work in Certo (`Process.exec` is a blocking `system()`/`popen` call
  with no cancellation handle today), out of scope for a Lume-only change;
  see the `process.run` note in "Standard scripting APIs" below, unchanged;
- ~~report stable test identifiers for filters and reruns~~ — shipped:
  every test result now carries a stable `id` (`<path>#<name>`, see
  "Shipped in the bootstrap" above); `--filter` matches against the
  full `id`, a strict superset of the old bare-name match, so a path
  fragment now disambiguates same-named tests across files and an
  `id` captured from one run can be fed straight back for an exact
  rerun.

### 4. Standard scripting APIs

- ~~path manipulation that is portable across Windows, Linux, and
  macOS~~ — shipped as `path.join/basename/dirname/extension/stem` (see
  "Shipped in the bootstrap" above); wraps Certo's own already-portable
  `Path.*` primitives, so no separator-handling logic exists on Lume's
  side at all;
- ~~directory enumeration~~ — shipped as `dir.list(path) -> Result<[str],
  str>` (see "Shipped in the bootstrap" above), one level, unsorted,
  names only;
- controlled recursive traversal — deferred: no `isDirectory`/`stat`
  primitive exists anywhere in Certo's stdlib to tell a directory entry
  from a file without an indirect, extra-syscall `listDir`-probing
  workaround, and no inode-based cycle detection is possible without one
  either, so "controlled" (a real depth or cycle bound) needs more design
  than a thin wrapper;
- ~~typed time and duration values~~ — partially shipped: `time.now() ->
  int` (Unix epoch seconds), `time.to_iso(seconds) -> str` (fixed UTC
  ISO-8601), `time.year`/`month`/`day`/`hour`/`minute`/
  `second(seconds) -> int` (UTC calendar components),
  `time.format(seconds, pattern) -> str` (`strftime`-style custom
  formatting), and now `time.in_timezone(seconds, zone)`/
  `time.format_in_timezone(seconds, pattern, zone) -> Result<str, str>`
  (IANA-zone-aware ISO-8601/custom formatting, `Err` for an unrecognized
  zone name), and now `duration.seconds`/`minutes`/`hours`/
  `days(n) -> int` (named-unit construction as plain epoch-second
  `int`s — `duration.minutes(5)` is `300`) are done (see "Shipped in
  the bootstrap" above); a distinct `Duration` *type* — its own value
  kind with dedicated arithmetic and unit tracking, not plain
  `int`-returning functions — remains deferred; Certo's stdlib already
  has one (a full `DateTime`/`Duration`/`Timezone`/`Date` API), so this
  is purely a scoping choice, not a feasibility gap;
- ~~richer process configuration~~ — partially shipped: stdin
  (`process.run_with_input`) and environment overrides
  (`process.run_with_env`) are done (see "Shipped in the bootstrap"
  above); working directory and timeout remain deferred — Certo's only
  working-directory-aware process call (`Process.spawnDetached`) is
  fire-and-forget with no output capture, and no timeout/cancellation
  primitive exists anywhere in Certo's process stdlib, so both need new
  C-level work in Certo itself, not just a Lume-side wrapper;
- ~~HTTP requests with typed results and bounded response handling~~ —
  partially shipped: `http.get`/`http.post`/`http.put`/`http.delete`/
  `http.request` (arbitrary methods and headers via `Map<str,str>`),
  and now `http.request_bytes`/`http.body_bytes` (see "Shipped in the
  bootstrap" above), are done; binary bodies shipped in a text-safe
  form — a Lume `bytes` value is represented exactly like `str`
  (embedded NUL bytes truncate on round-trip), since a genuinely
  NUL-safe `Bytes` type would need a change to Lume's runtime value
  representation, out of scope for now. True request-time (rather than
  post-download) response bounding remains deferred — it needs a
  streaming primitive that doesn't exist in Certo yet;
- ~~JSON encoding to complement typed decoding~~ — shipped as
  `json.encode(value) -> Result<str, str>` (see "Shipped in the
  bootstrap" above); supports the same shapes decoding does
  (`str`/`int`/`bool`/records/lists, recursively), plus enum values
  (`Option<T>`/`Result<T,E>` included), which decoding still doesn't.

Each API should keep the `noun.verb` naming convention and return explicit
`Option` or `Result` values rather than throwing exceptions.

## Later: ecosystem readiness

### Distribution and interoperability

- reproducible standalone executable builds;
- package signing and checksum verification;
- a stable bytecode version and compatibility policy;
- a narrow C ABI or subprocess-based interoperability story;
- release archives and installers for major desktop platforms.

### Developer experience

- richer completion, hover, definition, references, rename, and code actions;
- project-wide symbol indexing without slowing single-file checks;
- debugger protocol support after bytecode/source maps stabilize;
- generated API documentation;
- a compatibility and migration checker for language revisions.

### Performance engineering

- profile lexer, declaration scan, type substitution, verifier, and emitter;
- reduce allocation and string-copying hot spots;
- add persistent compiler-process measurements;
- add one-function incremental rebuild benchmarks;
- measure 100,000-line modules and multi-module projects;
- publish results across representative hardware.

The roadmap target remains 10,000 lines in under 10 ms. It should not be
presented as achieved until the implementation meets the benchmark contract.

## Deferred pending measurement

Structured concurrency may eventually use one explicit `spawn`/`await` model.
It remains deferred until real scripting workloads show that it is necessary
and measurements demonstrate an acceptable effect on compiler simplicity, AI
generation, and runtime behavior.

Other capabilities requiring evidence before design work include:

- mutable closure captures;
- statement-bodied closures;
- asynchronous I/O syntax;
- dynamic loading;
- user-defined serialization hooks.

## Non-goals for the core language

- macros and metaprogramming;
- operator overloading;
- exceptions;
- implicit truthiness or coercions;
- inheritance and implicit protocol conformance;
- runtime trait objects or dynamic protocol dispatch;
- borrow checking;
- compile-time execution;
- build scripts executed during compilation;
- multiple competing formatting styles;
- a GUI framework or unrestricted systems-programming surface.

## Release milestones

### 0.1 — Coherent bootstrap

- reconcile the specification, guide, examples, and API manifest;
- finish generic protocol-method dispatch;
- stabilize diagnostics and bytecode serialization;
- keep the complete smoke, test-runner, LSP, benchmark, and AI suites green.

### 0.2 — Practical automation

- ship typed maps, portable paths, directory operations, richer processes,
  time values, JSON encoding, and a minimal HTTP client;
- expand test discovery and CI output;
- validate representative shell/Python replacement programs.

### 0.3 — Reusable projects

- ship deterministic packages, lock files, local dependencies, and standalone
  executable builds;
- establish bytecode and language-version compatibility policies;
- publish cross-platform releases.

### 1.0 — Stable focused language

- freeze the core grammar and compatibility guarantees;
- meet the published compile-speed target on defined reference hardware;
- publish reproducible compiler and AI-generation benchmarks;
- provide dependable language-server, formatter, test, package, and release
  workflows.

## Maintaining this roadmap

When a feature ships:

1. update `ai/lume-api.json` through the compiler's API-manifest command;
2. update `SPEC.md`, the guide, examples, and diagnostics documentation;
3. record its compiler benchmark before and after the change;
4. add or update AI evaluation tasks;
5. move the item into **Shipped in the bootstrap** and link its tests or
   release milestone.

Roadmap order is directional, not a promise of dates. Benchmark evidence and
real automation workloads decide whether a proposed feature belongs in Lume.
