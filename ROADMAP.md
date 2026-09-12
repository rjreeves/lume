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
  in `BENCHMARKS.md`. This gate's own machinery is also unreliable at the
  sizes it would need to check: `lume benchmark <path> 20` — the standard
  multi-iteration harness — crashes with `certo panic: out of memory` on
  realistic-sized input (see the 0.1 milestone note below), so this gate
  could not have been checked with the recommended tooling even if someone
  had tried.
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
- *Stabilize diagnostics and bytecode serialization* — not assessed by this
  investigation.
- *Keep the complete smoke, test-runner, LSP, benchmark, and AI suites
  green* — **the benchmark suite is not green in a meaningful sense**: the
  `lume benchmark <path> 20` command used to produce median/p95 numbers
  crashes with `certo panic: out of memory` on a realistic-sized program,
  before completing. A single `lume check` of the same file succeeds, so
  this is a bug in the measurement tool, not only in the thing being
  measured — and it means every multi-iteration number this gate asks for,
  on anything beyond a trivial workload, currently cannot be produced at
  all.

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
- typed JSON decoding into records;
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

### Collections

- a built-in `Map<K, V>` — construction and lookup only
  (`map.new/len/get/set/has/remove/keys/values`), architecturally closer to
  `List<T>` (its own runtime value tag, no schema) than to the
  enum-backed `Option`/`Result`; no map literal syntax, construction is
  via `map.new()` only. Key type is restricted to `int`/`str`/`bool` — the
  same set the built-in `Eq` constraint already recognizes — deferred
  extension to records/lists/enums is a separate, later item alongside
  the general "equality and ordering through constraints" work.
  Iterator-style transforms (`map.map`/`filter`/`fold`) are not
  implemented yet — `map.keys`/`map.values` return plain lists that can be
  passed to the existing `list.*` transforms meanwhile.

### Scripting and tooling

- filesystem, environment, argument, string, JSON, list, result, and process
  APIs;
- process exit-code, standard-output, and standard-error inspection;
- human-readable and structured compiler errors;
- native test declarations, assertions, filters, and direct-child
  `*_test.lume` discovery;
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
- add canonical iterator-style map transforms (`map.map`/`filter`/`fold`),
  mirroring the existing `list.*` transforms;
- define equality and ordering support through constraints, extending
  `Map<K, V>`'s key type beyond `int`/`str`/`bool`;
- keep collection operations deterministic and easy for AI to select.

### 2. Packages and dependency resolution

- define a minimal package manifest and lock file;
- use explicit versions and deterministic resolution;
- separate dependency resolution from source compilation;
- support local packages before a public registry;
- cache resolved dependencies by content hash.

Package management must not introduce source-level package graph resolution
into every compilation.

### 3. Stronger test tooling

- recursively discover test files with explicit ignore rules;
- provide temporary-directory and environment fixtures;
- add structured test output for CI and editor integrations;
- support test timeouts and process-output assertions;
- report stable test identifiers for filters and reruns.

### 4. Standard scripting APIs

- path manipulation that is portable across Windows, Linux, and macOS;
- directory enumeration and controlled recursive traversal;
- typed time and duration values;
- richer process configuration: working directory, environment overrides,
  stdin, and timeout;
- HTTP requests with typed results and bounded response handling;
- JSON encoding to complement typed decoding.

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
