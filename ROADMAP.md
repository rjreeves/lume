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
- *Stabilize diagnostics and bytecode serialization* — assessed and
  fixed: eight issues found and fixed, the last (the scattered
  parser-level line-number cluster) landed across six PRs (#53, #57-#60,
  and this one). Fixed: (1)
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
  collision at its root. (3) of the ~125 line-less diagnostic codes found,
  the largest single cluster — the ~50 `checkBuiltinTypes`-originated
  codes covering `map.*`/`list.*`/`http.*`/`process.*`/`time.*`/`expect.*`
  builtin argument-type checks — now carry a real line number: its only
  caller, `checkCallTypes`, already held the calling instruction's line
  but discarded it; now threaded through and formatted into the existing
  `"E0NNN <message>"` messages as `"E0NNN line N: <message>"`, matching
  the convention ~90 other codes already used, so `diagnosticJson`'s
  existing `" line "`-searching `--json` extraction needed no changes and
  now reports the real line instead of `0` for this cluster. (4) the
  protocol-implementation cluster (`E0258`/`E0259`/`E0262`/`E0263`/
  `E0264`, five codes, not the two originally scoped — a second consumer
  of the same packed `functions.implementations` list turned up while
  fixing the first) — the line was already captured for three sibling
  codes right next to where the packed string is built but never carried
  into it; now appended as a fourth pipe field and read by both
  consumers. (5) `SPEC.md` §17 described an aspirational register-VM
  bytecode design (per-instruction register operands, a per-function
  register count and constants table, a compressed source map) that
  didn't match the actual flat stack machine at all — rewritten to
  describe the real `{op, text, number, line}` instruction shape, the
  pipe-encoded per-function marker-text convention, and the actual
  decode-time framing checks plus runtime catch-all that guard a loaded
  artifact (this same "register bytecode execution" phrasing was also
  independently wrong in this file's own "Shipped in the bootstrap"
  list, fixed alongside it). (6) `callBuiltin` — the *runtime* bytecode
  executor for builtin calls, as opposed to `checkBuiltinTypes`' compile-
  time typecheck — carried its own separate set of 21 line-less codes
  (several the runtime half of a code already fixed at the typecheck
  layer), all flowing through the exact same shape of choke point as
  fix (3): two callers (`callPure`, `execute`) already holding the
  dispatched instruction's line but discarding it, and one terminal
  return formatted the same way. These codes are only reachable by
  actually running a stale or hand-tampered bytecode artifact — no
  legitimate source construct triggers them, since a real call already
  passed static checking by the time it would reach this path — so no
  existing test exercised this path at all; a new test now does, via the
  same byte-patching technique fix (1)'s test already established. (7)
  the first three slices of the genuinely scattered parser-level cluster
  are now done — `parseCallArguments`' three codes (`E0103`, `E0105`,
  `E0106`), `parseLambda`'s seven codes (`E0122`-`E0128`), and all seven
  of `parseMatch`'s codes (`E0110`-`E0116`) — all now carry real line
  numbers; every site already had the right token in scope, needing no
  restructuring. `parseMatch`'s `E0113` ("unterminated match expression")
  needed one further fix first: any unterminated top-level function body
  (`match`-related or not) crashed the compiler outright (`certo panic:
  list index out of bounds`) rather than ever reaching a diagnostic,
  because `blockEnd` (src/lume.cto, the brace-depth scanner `scanFunctions`
  uses to find where each function/impl/type/test body ends) only
  guarded its scan on `index < List.len(tokens)`, not on the lexer's own
  EOF token — so an unclosed block scanned straight past EOF into
  genuinely out-of-bounds territory, and `scanFunctions`' next `at()`
  call (via `at`'s unchecked `List.getOrPanic`) panicked before
  `compileBlock`'s existing `E0202 unterminated block` check or
  `parseMatch`'s own `E0113` check ever ran. Fixed by also stopping
  `blockEnd`'s scan at the EOF token; both now report cleanly
  (`invalid_match_unterminated.lume`, `invalid_block_unterminated.lume`).
  The record-update syntax's five codes (`E0117`-`E0121`, the `value with
  { field: expr }` update expression — inline inside `parsePrimary`, not
  its own function despite the informal name) are done too; `E0120`
  ("unterminated record update") needed no extra fix, since it doesn't
  go through `blockEnd` and PR #58 had already removed the shared
  crash risk. `scanRecords`/`scanEnums` turned out to be mostly already
  done by an earlier, unrelated pass — only 4 codes were still bare
  (`E0230`/`E0236` in `scanRecords`, `E0240`/`E0248` in `scanEnums`); all
  four now fixed, same pattern, no crash risk (neither "unterminated"
  loop goes through `blockEnd` or has an unconditional trailing call).
  **The scattered cluster's last slice — the statement/declaration
  parser body — is now done too**: `compileBlock`'s nine bare codes
  (`E0202`-`E0207`, `E0212`-`E0214`) and `scanFunctions`' five remaining
  declaration-level codes (`E0221`, `E0223` at both its call sites,
  `E0225`, `E0250`) all now carry real line numbers, same pattern, no
  crash risk. `E0201` ("missing `fn main`") was deliberately left bare —
  it's a whole-program absence check with no natural source token to
  anchor a line to, the same category as the bytecode-artifact codes
  (`E0401`-`E0405`). Every parser-level diagnostic that has a meaningful
  source position now reports one.
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
- stack-based bytecode execution and a content-addressed bytecode cache.

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
  system* recognize what the operator already allowed. `Ord` is now
  extensible too, via `impl Ord for MyType { fn compare(a: MyType, b:
  MyType) -> int { ... } }` — unlike `Eq`, ordered comparison has no
  structural fallback, so `Ord` graduated from a hardcoded marker to a
  synthetic real protocol (seeded into the same `protocolNames`/
  `protocolSchemas`/`protocol_type` machinery every user-declared
  protocol already gets), requiring a genuine three-way `compare`
  method (negative/zero/positive, the `strcmp` convention) rather than
  an empty marker body. `<`/`<=`/`>`/`>=` on a value with an `Ord` impl
  dispatch to that method at runtime the same way `T.method()` protocol
  dispatch already does (`findFunction` + a `callPure` call — always
  through the pure interpreter regardless of caller, since a comparison
  should not have IO side effects). `==`/`!=` needed no changes, exactly
  like `Eq` — they already worked for a bare, even *unconstrained*,
  generic `T`, since that check only ever required both operand types
  to match, never a specific type. A bare `T`-typed value inside a
  generic function's own body can now also use `+`/`-`/`*`/`/`/`%`/
  `<`/`<=`/`>`/`>=` when `T` carries the matching constraint (`Number`
  for arithmetic, plus `Text` for `+` specifically mirroring the
  existing `str + str` case; `Ord` for ordered comparison) — found
  broken while building `Ord` above (confirmed for both `T: Ord` and
  `T: Number`, with plain `int` arguments, so it was unrelated to which
  concrete type a caller passed in: type-checking a generic body
  compared against the literal symbolic name `"T"`, which never equalled
  a concrete type). Fixed with **no runtime changes at all** — both
  `binary()` and `compare()`/`dispatchCompare()` already dispatch purely
  on the runtime value's own tag, never the static type label
  `verifyTypes` used, so the fix is entirely in `verifyTypes`: recognize
  `T` as the *current* function's own generic parameter (via the
  already-tracked `currentGenericConstraints`) and check its declared
  constraint instead of demanding a concrete type. A plain unconstrained
  `T` (or one constrained only by `Eq`/`Ord` when attempting arithmetic)
  still correctly fails — the checks are relaxed for the matching
  constraint, not removed.

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
  scripting APIs" below). Investigating the native test framework later
  found a real, confirmed-live bug here: a declared test's name and
  timeout live in the same pipe-delimited `function` marker string
  (`name|returnType|generics|constraints|testName|timeoutMs`), and
  `testName` is the one field taken verbatim from a user-written string
  literal rather than a pipe-free lexer token — so `test "a|b", timeout:
  50 { while true {} }` silently truncated the reported name to `a` and
  shifted `timeoutMs` onto non-numeric text, `parseInt`'s `?? 0`
  fallback then meaning "no timeout", hanging forever instead of
  failing after 50ms. Fixed by escaping a literal `|` in the declared
  name with a control byte (`Char.fromInt(1)`, unreachable through any
  of Lume's own string escapes) before it enters the marker, and
  reversing that when the name is read back out;
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
- ~~formatter and format checking~~ — shipped as `lume fmt <file>
  [--check]` (see "Shipped in the bootstrap" above's `--json` convention
  note, which already assumes `fmt`'s existence). Investigating it later
  found `fmt` had zero test coverage and a real bug: `formatSource`
  computed indentation by checking whether each line's own trimmed text
  starts with `}`/ends with `{`, with no awareness that `//` starts a
  comment or `"..."` is a string — so a comment like `// opens a block
  here {` desynced indentation for the rest of the file, and `fmt
  --check` false-flagged correctly-formatted code. Fixed by having
  `formatSource` compute that signal from a comment/string-stripped copy
  of each line instead of the raw line; `test.ps1` now covers `fmt`
  (previously untested) with a comment/string edge-case fixture,
  misindentation round-trip, and idempotency check. Left out of scope:
  `scanString` doesn't stop at a newline, so a string literal can
  technically span physical lines today, which `fmt`'s line-by-line
  model would still corrupt (inserting indentation into the string's
  own content — a semantics-changing bug, not just cosmetic) — no
  example or doc relies on that, so it's noted here rather than fixed;
- ~~language-server support~~ — shipped as a diagnostics-only MVP:
  `lume lsp` runs a persistent stdio JSON-RPC server implementing
  `initialize`/`shutdown`/`exit` and `textDocument/didOpen`/`didChange`/
  `didClose`, each publishing diagnostics via full-document sync
  (`TextDocumentSyncKind.Full`, matching Certo's own `certo-lsp` choice
  for `.cto` files). This was blocked all session on Certo having no way
  to read an exact byte count from stdin for LSP's
  `Content-Length: N\r\n\r\n`-framed transport — filed as Certo BACKLOG
  item 332, now shipped as `readBytes(n): Text`. Two more things were
  found while actually building it: Certo's C codegen doesn't escape a
  literal `\r` inside a folded Text constant, corrupting the generated C
  source (worked around here by building the carriage return at runtime
  via `Char.fromInt(13)` instead of a string literal — not filed as a
  BACKLOG item yet); and neither `print` nor `println` auto-flush stdout,
  which matters on a fully-buffered pipe (every LSP write here is
  followed by an explicit `flush()`). Still a real, known gap: `lume.cto`'s
  own compile pipeline only ever reports one error (a single
  `problem: Text` field with first-error-short-circuit throughout, not a
  list), so this MVP publishes at most one diagnostic per file — a real
  multi-diagnostic LSP needs that pipeline refactored first, a separate,
  much larger change. Later stress-testing against a deliberately
  adversarial client found every case tried (malformed JSON, missing
  `method`/`params`/`textDocument` fields, an empty `contentChanges`
  array) already degrades gracefully — except one real hang, confirmed
  live: a `Content-Length` header that parses as a valid but *negative*
  integer reached `readBytes` with that count and blocked forever (0%
  CPU, no response, no crash for an editor to notice and restart from).
  Fixed by having `lspReadContentLength` treat a negative value the same
  as an unparsable one, which the server already handled correctly (a
  clean exit, not a hang);
- ~~a machine-readable API manifest, compact AI generation contract, and
  fixed AI evaluation tasks~~ — shipped: `lume api`/`ai-reference`
  generate the manifest (used by `build.ps1` to write
  `ai/lume-api.json` on every build), and `ai/tasks.json` was expanded
  to exactly 100 fixed tasks, closed per the "Status report" section
  above (~line 158).

## Now: production scripting foundation

Full-shape generic protocol dispatch is complete (see "Shipped in the
bootstrap" above): a function constrained by `T: Protocol` or `T: A + B +
...` can call any of those protocols' methods on `T` (any shape with
exactly one `Self` parameter), resolved at runtime by a direct type-tag
check, with precise diagnostics for every failure mode found while
building it, and a dedicated benchmark confirming the mechanism scales
linearly. That milestone is closed; this one — production scripting
foundation — is next.

Adversarially testing this area later (Self in a non-first parameter
position, dispatch from inside closures, three-way multi-constraint
ambiguity) found it solid, plus one real, previously-undocumented gap:
`&T.method` (taking a generic dispatch as a first-class function value,
e.g. to pass into `list.map`) reported `E0216 unknown function` -
identical to a genuine typo, with no hint that the actual issue is
specific to generic dispatch. Root cause: a plain `T.method(...)` call
gets a deliberate exemption in `validateExpression` deferring to
`verifyTypes`'s full generic-dispatch validation, but `&T.method`
compiles to a different instruction (`fn_ref`) that exemption was never
extended to. Fixed with a precise `E0740` instead - not full runtime
support for calling generic dispatch indirectly through a function
value, which would need dispatch-at-call-time support added everywhere
an `"f:"`-tagged value gets invoked, a materially larger change to a
core mechanism.

Investigating JSON encode/decode edge cases afterward found the area
largely solid too (nested enum fields inside a record, nested
`Option<T>` fields, both directions - all decode and encode correctly)
except one confirmed gap: `SomeType.from_json(...)` failed at runtime
inside any closure or test body with `callback uses unsupported
operation \`decode_json\`` - confirmed live inside a native `test`
block. `json.encode` already worked in that same restricted context;
`decode_json` simply had no handler in `callPure` at all, only in
`execute()`. Unlike the `&T.method` gap above, this one was cheap to
close properly rather than just document: `decodeRecordJson` is a pure
function (`Json.parse` plus recursive schema lookups, no `[io]`), so
`callPure` now handles `decode_json` directly, mirroring `execute()`'s
own handling exactly - `from_json` now works inside closures and test
bodies for real.

### 1. Complete collections

- ~~add a typed `Map<K, V>` with a deliberately small API~~ — shipped (see
  "Shipped in the bootstrap" above);
- ~~add canonical iterator-style map transforms (`map.map`/`filter`/
  `fold`), mirroring the existing `list.*` transforms~~ — shipped (see
  "Shipped in the bootstrap" above);
- ~~define equality support through constraints, extending `Map<K, V>`'s
  key type beyond `int`/`str`/`bool`~~ — shipped for `Eq` via explicit
  `impl Eq for MyType {}` (see "Shipped in the bootstrap" above);
  ~~`Ord` for compound types~~ — shipped too, via a real per-type
  `impl Ord for MyType { fn compare(a, b) -> int { ... } }` (see
  "Shipped in the bootstrap" above);
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
- ~~enforce per-package dependency isolation~~ — shipped, closing a
  real gap found while reviewing the packaging system: any package
  could `use` any other package present anywhere in the resolved
  tree, whether or not it declared that package as its own
  dependency, purely because `lume.lock.json` was one flat list and
  `loadModule` (`src/lume.cto`) threaded it through every recursive
  call unchanged — confirmed live with a diamond graph (`app` →
  `foo`/`bar`, both → `baz`) where `foo` successfully called into
  `bar` despite never declaring it, purely because `bar` happened to
  be some *other* dependency of the root app. `examples/packages/app`
  itself demonstrated the exact pattern (`app.lume` used
  `formatting.fmt` directly while only declaring `mathutils`;
  `formatting` was only ever declared by `mathutils`) — fixed by
  adding `formatting` to `app/lume.json` directly, since it's a real,
  honest dependency. Each `lume.lock.json` entry now also records its
  own declared dependency names, and a new top-level `"direct"` field
  records the root app's own; `loadModule` carries both the full flat
  list (still needed to locate any resolved package's files) and a
  second, narrower "currently visible" list that only widens when
  resolution actually crosses into a declared dependency, using
  *that* dependency's own declared names from then on — all computed
  once at `install` time, so ordinary `run`/`check`/`test` still does
  zero resolution work, unchanged from this section's own closing
  constraint below. An undeclared cross-package `use` now falls
  through to the same `E0701 cannot read module` error a genuinely
  missing module already produces — no new error code needed;
- ~~consistent manifest error codes~~ — a systematic scan of every
  `E0NNN` code for accidental reuse found one real inconsistency: "the
  manifest can't be read" and "the manifest is malformed (missing
  `name`/`version`)" were two genuinely different conditions, but each
  got reported under whichever of `E0705`/`E0706` its caller happened
  to pick — the same condition landed on a different code depending
  only on whether it was the root package's own manifest
  (`installPackages`) or a dependency's (`resolveDependencies`), and
  each code covered both unrelated conditions. Root cause:
  `installPackages` reimplemented manifest validation inline instead
  of calling the existing shared `readManifestVersion` helper that
  `resolveDependencies` already used, so the two independently drifted.
  Fixed by making `readManifestVersion` the single source of truth —
  its two `Err` cases now carry their own codes directly (`E0705`
  unreadable, a new `E0737` malformed), and every caller propagates the
  message as-is instead of re-deriving or re-wrapping a code (`E0706`
  is retired, not reassigned, consistent with this file's own
  monotonic code numbering);
- ~~detect a corrupted lock file~~ — investigating package installer
  edge cases (self-referencing dependencies already worked correctly,
  caught as `E0709` with no crash) found `loadPackageContext` read and
  parsed `lume.lock.json` with no shape validation: a present-but-
  invalid file (bad JSON, or valid JSON missing `resolved`/`direct` as
  arrays) silently fell back to an empty dependency list rather than
  reporting a problem. Confirmed live on a real two-package project:
  three different corruption modes (invalid JSON, an empty `{}`, and a
  resolved entry missing its own `path`) all produced the same
  misleading `E0701 cannot read module` pointing at a path that looked
  like a local-import mistake, with nothing indicating the real cause
  was the lock file. Only the file's *absence* is meant to mean "no
  dependencies" (an ordinary project with neither file); fixed by
  giving `PackageContext` a `problem` field, set when the file exists
  but doesn't have the shape `lume install` always writes, reported
  through `loadProgram`'s existing `ModuleLoad.problem` path as a new
  `E0738`;
- ~~detect a stale lock file~~ — `run`/`check`/`test` reading only
  `lume.lock.json`, never the manifest, is an intentional, already-
  documented constraint (zero resolution work on ordinary runs), not a
  bug — confirmed live that editing `lume.json` (e.g. dropping a
  dependency) without re-running `install` leaves the app still able
  to `use` the now-undeclared dependency, silently, via the untouched
  lock file. The real gap was that nothing, not even optionally, could
  detect this drift: a manifest and its lock file can go out of sync
  the same way `package-lock.json`/`Cargo.lock` can in other
  ecosystems, either sharing the drift silently (if the stale lock
  file is committed) or failing confusingly in CI in a way that
  never reproduces locally (if it's regenerated fresh there). Shipped
  `lume install <dir> --check`, mirroring `npm ci`/`cargo build
  --locked`: re-resolves exactly like plain `install`, but compares the
  result against the existing lock file byte-for-byte instead of
  overwriting it, reporting a mismatch (including "no lock file yet")
  as a new `E0739` and never writing — an opt-in CI gate that leaves
  `run`/`check`/`test`'s own zero-resolution-work guarantee untouched;
- cache resolved dependencies by content hash — deferred: not
  meaningful yet for local paths (reading a local directory has no
  fetch cost to cache); revisit once packages can come from anywhere
  other than the local filesystem.

Package management must not introduce source-level package graph resolution
into every compilation.

### 3. Stronger test tooling

- ~~recursively discover test files~~ with explicit ignore rules —
  shipped: `lume test <dir>` finds `*_test.lume` files in subdirectories
  too, not just the given directory (a fixed internal 32-level depth
  bound, not user-configurable), once Certo shipped `isDirectory`
  closing BACKLOG item 329 (which also confirmed the underlying
  `stat`/`S_ISDIR` mechanism already existed internally in Certo's C
  runtime, used by its own recursive-delete helper, just wasn't exposed
  as a callable builtin) — verified directly against a freshly built
  `certo.exe` before wiring it in. ~~Explicit ignore rules~~ now shipped
  too: `--ignore name1,name2` skips recursing into any subdirectory
  whose own name exactly matches one in the comma-separated list (e.g.
  `--ignore node_modules,.git`), via a new `walkDirIgnoring` mirroring
  `walkDir` exactly rather than changing the public `dir.walk` builtin's
  own documented behavior. No default ignore list - nothing is skipped
  unless the flag says so;
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
- ~~controlled recursive traversal~~ — shipped as `dir.walk(path,
  maxDepth) -> result<[str],str>` (see "Shipped in the bootstrap"
  above), same upstream unblock (Certo BACKLOG item 329) as recursive
  test discovery above. A real depth bound, per this bullet's own
  original "depth *or* cycle" wording — true inode-based cycle
  detection would need a `stat` primitive beyond `isDirectory` (which
  only classifies file-vs-directory, not inode identity), so a
  symlink loop is still only bounded by `maxDepth`, not detected as a
  cycle; explicitly out of scope, unchanged from this bullet's own
  original assessment;
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
- ~~richer process configuration~~ — shipped: stdin
  (`process.run_with_input`), environment overrides
  (`process.run_with_env`), and now working directory and a real
  timeout (`process.run_with_options(exe, args, workingDir, timeoutMs)`,
  see "Shipped in the bootstrap" above) are all done. The last two were
  blocked on Certo BACKLOG item 330 (Certo's only working-directory-aware
  call, `Process.spawnDetached`, had no output capture, and no exec
  variant had a timeout/cancellation handle) until Certo shipped
  `Process.run` to close it — verified directly (output capture, working
  directory, and a real ~5.5s command cut off at exactly the requested
  timeout, all confirmed against a freshly built `certo.exe`) before
  wiring it in. A timed-out and a failed-to-spawn process are currently
  indistinguishable from Lume (`process.code(result) == -1` for both,
  since `CertoProcessResult` has no separate timed-out flag) — a known,
  documented limitation, not something Lume can resolve without a
  further upstream change;
- ~~HTTP requests with typed results and bounded response handling~~ —
  shipped: `http.get`/`http.post`/`http.put`/`http.delete`/
  `http.request` (arbitrary methods and headers via `Map<str,str>`),
  and `http.request_bytes`/`http.body_bytes` (see "Shipped in the
  bootstrap" above), are done; binary bodies shipped in a text-safe
  form — a Lume `bytes` value is represented exactly like `str`
  (embedded NUL bytes truncate on round-trip), since a genuinely
  NUL-safe `Bytes` type would need a change to Lume's runtime value
  representation, out of scope for now. Request-time (rather than
  post-download) response bounding is now real too, once Certo shipped
  `Http.requestWithLimit`/`HttpResponse.truncated` closing BACKLOG item
  331: the five functions above now stop reading at a fixed 10 MiB
  instead of downloading further before rejecting an oversized
  response (same observable `Err` behavior as before, verified
  unchanged against a live endpoint), and a new
  `http.request_with_limit(method, url, headers, body, maxBytes) ->
  result<http,str>` lets a caller choose their own limit — unlike the
  five fixed functions, it never auto-errors on truncation; a new
  `http.truncated(response) -> bool` reports whether the body was cut
  off, so the caller decides. `http.request_bytes` is unaffected — the
  new Certo function's body parameter is `Text`, not `Bytes`, an honest
  scope boundary, not an oversight;
- ~~JSON encoding to complement typed decoding~~ — shipped as
  `json.encode(value) -> Result<str, str>` (see "Shipped in the
  bootstrap" above); supports the same shapes decoding does
  (`str`/`int`/`bool`/records/lists, recursively), plus enum values
  (`Option<T>`/`Result<T,E>` included). ~~Typed JSON decoding into enum
  values~~ — shipped too: `EnumName.from_json(text)` decodes the same
  `{"variant": "Name", ...fields}` shape `json.encode` already produces,
  reusing every schema helper `encodeJsonTree`/`bindVariantPayload`
  already established (`findEnumSchema`, `variantPayloadSchema`) —
  purely a new branch in the existing `decodeJsonValue`, no parser,
  runtime-instruction, or type-checker restructuring beyond widening
  the `.from_json` dispatch's own type-name check to accept an enum
  name alongside a record name.

Each API should keep the `noun.verb` naming convention and return explicit
`Option` or `Result` values rather than throwing exceptions.

### 5. Core language ergonomics

Started as three real gaps found while writing a non-trivial example
program (`examples/game_of_life.lume`, a Conway's Game of Life on a
toroidal grid), later joined by two more found while writing the full
user manual (`docs/using-lume-the-fast-one.md`) — none blocked on
anything upstream, each confirmed by a direct empirical test against
the real compiler rather than assumed from the grammar. Not every one
turned out to be small: `and`/`or`/`not` and `if`/`else`-as-expression
are now shipped (the latter needed real new instructions, not just a
parser tweak — see its own entry below for why); the `Result`/`Option`
asymmetry and the no-chained-field-access limitation are confirmed,
real, and filed, but are design questions rather than bounded fixes:

- ~~no boolean `and`/`or`/`not` operators exist at all~~ — shipped,
  with genuine short-circuit evaluation (deliberately verified with a
  test that proves the right operand is never *evaluated* when the
  left already determines the result, not just that the boolean
  output is correct — this session separately found and filed a Certo
  interpreter bug, BACKLOG item 326, where Certo's own `and`/`or`
  don't short-circuit despite the spec saying they do, so Lume's own
  implementation got extra scrutiny here). Needed zero new runtime
  instruction types and zero `verifyTypes`/VM changes: `and`, `or`,
  and `not` all compile to the same `jump_false`/`jump`/`const_bool`
  instructions `if`/`else` already emits, via a new `parseOr →
  parseAnd → parseNot → parseComparison` precedence level (`not`
  binds tighter than `and`, which binds tighter than `or`) wired in at
  all 15 sites that previously called `parseComparison` directly as
  "the top-level expression parser". `verifyTypes`'s existing
  `jump_false` handling already required and popped a `bool`, so
  operand-type checking (`E0617`) came for free;
- ~~no `if`/`else` expression form~~ — shipped, in statement context
  only (`let x = if cond { a } else { b }` now works; using the same
  shape inside a closure body compiles but fails at runtime with
  "unsupported operation", exactly like `match` already does there —
  a deliberate scope match, not an oversight, confirmed with the
  user before implementing). Turned out to need much more than the
  `and`/`or`/`not` precedent: those got away with zero new
  instructions because both branches are always `bool`, so the type
  checker's linear, jump-blind walk (`for item in code` in
  `verifyTypes`, no jump-following) harmlessly over-counts a
  correctly-typed `bool` that's never popped by anything (verified
  directly with adversarial cross-type tests before trusting it). A
  general if-expression can't get that free ride — `if cond { 5 }
  else { "text" }` must be rejected — so this needed the same
  mechanism `match` already uses to solve exactly that problem: three
  new instructions (`if_expr_start`/`if_expr_then_end`/
  `if_expr_finish`, mirroring `match_start`/`match_arm_end`/
  `match_finish`) backed by a new `IfExprContext` that captures a
  stack baseline before branching, resets between the two branches,
  and explicitly compares their types (new `E0736`) before pushing
  one merged result. `callPure` needed no changes at all - leaving
  the three new op names unhandled there routes straight into its
  existing generic "unsupported operation" fallback, the same free
  ride `match` already gets;
- ~~no way to convert an `int` to `str`~~ — shipped as
  `str.from_int(n) -> str`, mirroring `time.to_iso`'s own `(int) ->
  str` shape exactly (same 3-site builtin pattern: `builtinNames`/
  `builtinCounts`, `checkBuiltinTypes`, `callBuiltin`, using Certo's
  own `intToText`, already used pervasively throughout this file's
  own implementation). `examples/game_of_life.lume`'s `intText` helper
  was simplified from the `result.value(json.encode(n))` workaround
  that motivated this fix to a direct `str.from_int(n)` call, with
  identical output confirmed before and after.

Two more real gaps found while writing a full user manual
(`docs/using-lume-the-fast-one.md`), each confirmed by a live compile/
run against the real compiler, not assumed:

- **there are two separate, non-interchangeable `Result` conventions,
  and nothing in this repository documented the split before now** —
  the `Result<T, E>` enum a program constructs by hand with
  `Result.Ok(...)`/`Result.Err(...)` (matchable with `match`), versus
  the lowercase `result<T, E>` every `fs.try_read_text`/`fs.read_bytes`/
  `dir.list`/`dir.walk`/`http.*`/`Type.from_json`/`EnumName.from_json`
  builtin actually returns (readable only via `result.is_ok`/
  `result.value`/`result.error`, never `match`, and not assignable to
  or returnable from a signature declared with the capitalized type).
  Confirmed directly: `match` on a builtin's return is `E0650 match
  requires an enum`; returning a builtin's `result<T,E>` from a function
  declared `-> Result<T, E>` is `E0618 type mismatch`; and
  `result.is_ok` on a hand-constructed `Result.Ok(...)` value is `E0622
  result operation requires result value`. `Option<T>` has no such
  split — every source of an `Option` (`list.find`, `map.get`, or a
  hand-declared `-> Option<T>` function) interoperates freely with
  `match`. This asymmetry is confirmed, not yet designed around or
  fixed — filing it here since a consumer (this manual, and presumably
  any AI generating Lume from a prompt) needs to know it exists, even
  before deciding whether the two conventions should be unified;
- **a function call's return value cannot have a field accessed
  directly** — `result.value(decoded).name` is a syntax error (`E0206
  expected )`); the call's result must be bound to a `let` first, then
  the field read off that binding. **Scope corrected after further
  investigation**: this is not a small, bounded parser fix. The lexer
  treats a whole dotted name (`user.name`, `str.len`, `Result.Ok`) as
  one identifier token (`isAlphaNumeric` includes `.`); every dotted
  access in this compiler is a string-split on that one token's text
  (`beforeDot`/`afterDot`/`Text.split(..., ".")`), not a recursive
  postfix-application grammar production. `)` ends that token, so
  there is no mechanism at all for attaching a trailing `.field` onto
  an arbitrary expression (a call, a parenthesized expression, and so
  on) — real support would mean inventing a genuine postfix-parsing
  loop and changing how every existing dotted form (`str.len`,
  `list.map`, `Result.Ok`, `User.from_json`, namespaced builtins in
  general) is recognized, not a quick, isolated addition.

None of these blocked the manual's own examples once corrected, but
they're real ergonomic gaps for a language whose own stated top-level
principle (see "Product principles" above) is "reliable AI generation"
— an AI generating Lume code has to already know these five specific
things rather than writing the obvious thing.

## Later: ecosystem readiness

### Distribution and interoperability

- ~~reproducible standalone executable builds~~ — confirmed and fixed,
  though the actual fix lives in Certo, not here: building `lume.cto`
  twice (same toolchain, same machine, same output filename, seconds
  apart) produced binaries differing in exactly one 4-byte field out
  of ~650KB - the PE COFF `TimeDateStamp` lld-link embeds by default
  on Windows. Fixed upstream by adding `-Xlinker /Brepro` to Certo's
  Windows link step ([rjreeves/Certo#2](https://github.com/rjreeves/Certo/pull/2),
  merged), verified end to end after rebuilding the toolchain:
  `sha256sum` now matches exactly across repeated builds, both via a
  direct `certo` invocation and through this project's own
  `build.ps1` (including its build-hash templating step), with the
  full `test.ps1` suite passing unchanged against the rebuilt binary.
  Windows-only - other platforms use a different linker path entirely
  and weren't measured or touched;
- package signing and checksum verification;
- ~~a stable bytecode version and compatibility policy~~ — the
  version-*format* half was already covered (`LBC4`'s own magic
  number), but investigating the `.lbc` cache directly found a real,
  confirmed-live gap the format alone didn't close: `compileOrCache`
  (`src/lume.cto`) keyed a cache hit purely on the program's own
  source hash, with no way to tell "this source is unchanged" apart
  from "this source is unchanged *and the compiler that produced this
  bytecode is still the one running*" — upgrading `lume.exe` (even
  for a real bug fix) left any untouched `.lume` file's stale,
  pre-fix bytecode cached indefinitely, with no way to detect it short
  of manually deleting the `.lbc` or touching the source. Fixed by
  bumping the format to `LBC5` and embedding a build-time hash of
  `lume.cto`'s own source (computed by `build.ps1`, substituted into a
  placeholder constant before invoking Certo) alongside the existing
  program-source hash; either mismatch is now treated as a cache miss.
  Verified live: patching a real cache's embedded build-hash field to
  simulate "same program, different compiler build" correctly forced a
  transparent recompile with the right output, and rewrote the cache
  with the real hash afterward;
- a narrow C ABI or subprocess-based interoperability story;
- release archives and installers for major desktop platforms.

### Developer experience

- ~~richer completion, hover, definition, references, rename, and code
  actions~~ — partially shipped: `textDocument/definition`
  (go-to-definition), the first of the six chosen as the cheapest to
  build on `scanFunctions`/`scanRecords`/`scanEnums`'s existing
  declaration data. Required two foundational pieces first: `Token`
  gained a `column` field (LSP positions are `{line, character}`, but
  `Token` only tracked `line`), and the server gained a document
  store, since `textDocument/definition` requests carry only a URI and
  a position, not source text, unlike `didOpen`/`didChange`. Building
  that store surfaced a real, confirmed finding along the way: Certo's
  `Map` is pointer-equality keyed by design
  (`crates/stdlib/src/collections.rs`), so a `Map<Text, Text>` keyed
  by URI silently failed every lookup once the key Text came from a
  *different* JSON-RPC message than the one that inserted it, even
  though `Text.eq` on the two values was `true` - the document store
  is two parallel lists searched by `Text.eq` instead (open documents
  in one LSP session number in the single digits, so the O(n) scan
  costs nothing that matters). Resolution is flat and name-based (no
  type/scope awareness - two declarations sharing a name resolve to
  whichever appears first in the file) and single-file only (an
  imported symbol's definition isn't found). `textDocument/hover`
  followed, reusing the same declaration index plus three existing
  pure helpers (`parameterNames`/`parameterTypes`/
  `functionReturnType`, already built for `scanFunctions`' protocol-
  method handling) to show a function's full signature with no new
  parsing; a record/enum name shows only the bare `"type Name"`/
  `"enum Name"` line, since their field/variant lists aren't exposed
  by a standalone-reusable helper the way a function's signature is -
  a smaller follow-up if wanted later. Surfaced a separate, more
  significant finding along the way, deliberately not fixed in that
  PR and spawned as its own task instead: `textDocument/didOpen`/
  `didChange` on source with an incomplete function signature (the
  single most common state while a user is actively typing) crashed
  the *entire* `lume lsp` server process, not just that one request.
  ~~Fixed~~: `parameterNames`/`parameterTypes`/`functionReturnType`/
  `typeNext`/`genericParameters`/`genericConstraints` (all in the same
  small, self-contained block of token-walking helpers a function's
  parameter list, generic parameter list, and type references are
  parsed with) had at least one `while` loop with no `eof` bound each
  - a different instance of the same general class the parser-level
  error-code audit above already fixed once for `blockEnd`, in a
  different function. Added the same `eof`-bound idiom used everywhere
  else in the file to each; verified against the original repro plus
  four sibling malformed shapes (an unclosed generic parameter list, an
  unclosed generic type reference, a bare parameter name at end of
  file, an unclosed record field type) - all now report a diagnostic
  instead of panicking, and the LSP server stays fully responsive
  after receiving one via `didOpen`. `textDocument/references` and
  `textDocument/rename` shipped together (both reduce to the same
  core - every `name`-kind token in the file matching a given name,
  simpler than the declaration index since it needs no keyword-
  adjacency check; rename just re-emits that same list as a
  `WorkspaceEdit` instead of `Location[]`). Two explicit v1 skips:
  `references`' `context.includeDeclaration` flag isn't read (the
  response always includes the declaration), and `rename` doesn't
  validate `newName` is a legal identifier before building the edit
  (a genuinely bad rename surfaces via the compiler's own diagnostics
  on the next compile, same as any other invalid identifier).
  `textDocument/completion` closes out five of the six candidates -
  the one genuinely different in kind from the other five, since it
  has to suggest names *before* the user finishes typing one, which
  normally means real scope resolution (locals, parameters, imports,
  shadowing). Scoped down to match this arc's own established
  trade-off instead: every builtin name (`builtinNames()`, the same
  data `lume api`/`lume api-docs` already expose) plus every file-
  local `fn`/`type`/`enum` declaration, unfiltered by cursor position
  or partial-word prefix - real editors already fuzzy-filter
  completion items against whatever's typed client-side, so this
  isn't a workaround, just the same flat/name-based scope this arc
  chose five times already. Only code actions, plus cross-file
  resolution for every capability above, remain open;
- project-wide symbol indexing without slowing single-file checks;
- debugger protocol support after bytecode/source maps stabilize;
- ~~generated API documentation~~ — shipped as `lume api-docs`, a
  human-readable Markdown builtin reference (`docs/builtins.md`,
  regenerated by `build.ps1` on every build, same as `ai/lume-api.json`)
  grouped by namespace. Deliberately sourced from the exact same
  `builtinNames()`/`builtinCounts()` data `lume api`'s JSON manifest
  already reads, rather than a separately hand-maintained document, so
  it can't drift from the real compiler the way a hand-written
  reference could. Name and arity only — per-parameter types and
  descriptions aren't available from any single authoritative source
  in the compiler today (scattered across ad-hoc validation chains in
  `checkBuiltinTypes`/`callBuiltin`, not a structured table); closing
  that gap would need a larger refactor, not attempted here;
- a compatibility and migration checker for language revisions.

### Performance engineering

- ~~profile lexer, declaration scan, type substitution, verifier, and
  emitter~~ — partially shipped as `lume profile <file> [iterations]`
  (see `BENCHMARKS.md`'s "Phase profiling" checkpoint): `lex()` and the
  declaration scan (`scanRecords`/`scanEnums`/`scanFunctions`) are
  timed precisely, since both are already separately callable pure
  functions. Type substitution, verifier, and emitter stay one
  combined, explicitly-labeled-`estimated` bucket — `compile()` fuses
  per-function codegen, `verifyTypes`, and `patchGenericDispatch` with
  no seam between them, and separating them cleanly would mean either
  changing `CompileResult`/`compile()`'s signature (used by every
  command: `run`/`check`/`test`/`build`/`lsp`) or duplicating its
  ~140-line body purely for instrumentation — not attempted here. The
  3-bucket data found a real, actionable result: lexing alone is
  roughly 33-42% of total compile time on both 10,000-line benchmark
  programs, not a rounding error — the highest-leverage target if
  compile-time work continues, ahead of further verifier/emitter
  micro-optimization;
- ~~reduce allocation and string-copying hot spots~~ — partially
  shipped: `lume profile` (above) pointed straight at `lex()`'s
  per-character classification (`isDigit`/`isAlpha`/`isAlphaNumeric`, a
  heap-allocated single-character `Text` from `charAt` plus a
  `Text.contains` string search, for every character of every source
  file). Rewritten to use Certo's `Bytes.byteAt`/plain `Int` codes
  instead — measured ~66x faster in isolation, and a real ~29-38%
  wall-clock reduction on the two 10,000-line benchmarks end to end
  (see `BENCHMARKS.md`'s "Lexer rewrite" checkpoint). `charAt`'s other,
  far-colder callers and `scanString`'s own value-accumulation
  (`Text.++` in a loop) were left untouched — this closes the specific
  allocation hot spot `lume profile` found, not every one that might
  exist;
- ~~reduce allocation and string-copying hot spots (second instance)~~
  — the scope-resolution bucket hash (`hashName`, called on every name
  insert/lookup/contains check across declaration scanning,
  verification, and codegen) had the same allocate-per-character
  pattern: `characterIndex` did a linear `Text.indexOf` scan through a
  63-character alphabet against a heap-allocated single-character
  `Text`. Rewritten to a byte-code version (`Bytes.byteAt` plus plain
  range/offset arithmetic, no allocation, no scan) — measured ~9.8x
  faster in isolation, and end to end (see `BENCHMARKS.md`'s "Bucket
  hash rewrite" checkpoint) a further ~14-23% wall-clock reduction on
  top of the lexer rewrite above, bigger than the isolated probe alone
  suggested since `hashName` runs throughout scan, verify, and codegen,
  not just one phase;
- ~~reduce allocation and string-copying hot spots (third instance)~~ —
  unlike the previous two (constant-factor allocation costs),
  `scanString`'s value accumulation (`value = value ++ charAt(...)`,
  one heap-allocated single-character `Text` concatenated per
  character of every string literal) was a genuine **complexity-class**
  bug: Certo's `++` (`certo_text_concat`) is a flat `malloc`+`memcpy`
  with no rope/tree structure, so appending one character at a time is
  O(n²) in the literal's length, confirmed by reading Certo's own
  runtime C source directly. Rewritten to accumulate via
  `Text.sliceUnchecked` over runs of unescaped characters (flushed only
  at an escape or the closing quote), already the same pattern used for
  token text elsewhere in `lex()` — measured ~31x faster in isolation
  on a 203-character string and ~142x on a 2003-character string (the
  widening gap with length is the O(n²)→O(n) signature), and ~14.9x
  faster end to end on a throwaway benchmark with fifty ~2000-character
  string literals (153.87ms → 10.30ms per compile, byte-identical
  output). The two 10,000-line benchmark files are unaffected (no long
  string literals in compiler-generated source), as expected;
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
