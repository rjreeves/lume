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

## Status report (2026-09-11, updated same day after the lexer and verifyTypes fixes)

A direct check of where the bootstrap stands against the gates and the 0.1
milestone above, based on the measurements in
[`BENCHMARKS.md`](BENCHMARKS.md) rather than on what any single feature's
own commit claimed. Read this alongside that file's dated sections, which
this summarizes without repeating. This section was first written before
the fixes below existed; it has been updated in place rather than left
stale, since an inaccurate status report defeats its own purpose.

**Performance gates: still not met, but no longer purely structural — three
real bugs have been found and fixed, with one concrete, order-of-magnitude
result, and two more mechanisms identified with the hunt ongoing.**

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
  generics, closures mixed)**: only ~35% faster (21,563 ms → 14,125 ms,
  now ~1,412x over the 10 ms target rather than ~2,150x) — because its
  dominant cost was never the lexer. Closures and generics each ride at
  least one more quadratic mechanism of their own. Closures' mechanism
  (`validateExpression`'s own `activeNames` tracking, a fourth instance of
  the same scan/copy pattern) is now identified but deliberately left
  unfixed — its save/restore is a genuine scope-leak correctness check
  (`E0210`), not a redundant safety net, so it needs a structurally
  different fix (a small per-closure delta stack, not a copied combined
  list) rather than the pattern that worked for the other three. Generics'
  remaining mechanism has not been located at all.
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
- The AI evaluation suite this file's own gate depends on
  ("added to the fixed AI evaluation suite") has 7 tasks; `BENCHMARKS.md`
  specifies "at least 100."

**0.1 "Coherent bootstrap" milestone: partially met, one item actively
false.**

- *Reconcile the specification, guide, examples, and API manifest* —
  in progress rather than done. `SPEC.md` was reconciled against the
  compiler once and has already needed follow-up correction as other work
  landed underneath it; that is expected of a document tracking a moving
  target, but it means "reconciled" is not yet a stable, closed state.
- *Finish generic protocol-method dispatch* — not done; this file's own
  "Now" section above says so, and the benchmark data independently
  confirms it: a generic function constrained by a user protocol gets no
  compile-time benefit over an unconstrained one today.
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
at every size tested. And as of this update, the compile-speed gap is no
longer purely theoretical or purely structural: three concrete root causes
have been found (one in Certo's own `Text.slice`, two in `lume.cto`),
fixed, and verified, with a genuine ~7x, complexity-class-changing result
for the common case. The remaining gap is now narrower and better
understood — two more mechanisms, one identified, one not — rather than one
undifferentiated "everything is quadratic" floor.

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
- no trait objects, virtual calls, or runtime protocol lookup.

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

## Now: complete static protocol dispatch

Protocol methods exist for concrete types. The next milestone is to make them
fully useful inside generic code while retaining compile-time resolution.

- allow a function constrained by `T: Protocol` to invoke protocol methods on
  values of `T`;
- resolve each call after generic type inference without dynamic dispatch;
- support multiple constraints such as `T: Eq + Named`;
- produce precise diagnostics for missing implementations, ambiguous method
  names, and incorrect receiver or payload types;
- add generic protocol-call tests, AI examples, and a 10,000-line benchmark.

Completion means constrained generic algorithms can call required methods and
all dispatch is visible to the compiler before bytecode execution.

## Next: production scripting foundation

### 1. Complete collections

- add a typed `Map<K, V>` with a deliberately small API;
- add canonical iterator-free transformations where they reduce boilerplate;
- define equality and ordering support through constraints;
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
