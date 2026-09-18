# Using Lume — The Fast One

## A practical guide to small, safe, fast automation

Lume is a focused scripting language for work that has outgrown a shell script
but does not need a large application stack. It combines short programs,
static checking, structured data, explicit errors, fast compilation, and a
small API surface that is easy for people and AI systems to learn.

This book describes the language **as the current bootstrap compiler
(`src/lume.cto`) actually implements it**, verified against a real built
`dist/lume.exe` rather than assumed from design documents. Where this
repository's other documents (`README.md`, `SPEC.md`) describe a larger,
aspirational design — string interpolation, bracket-generic JSON decoding,
`value ! error` return types, bare `use fs`-style imports — none of that
exists in the bootstrap today; this book does not use it. Its examples are
designed to be copied, checked, and run exactly as written. The
machine-readable source of truth for exact builtin names and arities is
always [`ai/lume-api.json`](../ai/lume-api.json), regenerated on every build.

---

## Contents

1. Why Lume
2. Your first program
3. Values, bindings, and expressions
4. Control flow — and what Lume deliberately leaves out
5. Functions and recursion
6. Lists and transformations
7. Records and immutable updates
8. Enums and exhaustive matching
9. Generics, constraints, and protocols
10. Option and Result
11. Typed maps
12. JSON: encoding and decoding
13. Files and paths
14. Processes and environment values
15. HTTP requests
16. Bytes
17. Time and duration
18. Modules
19. Packages
20. Testing
21. Building, bytecode, and performance
22. Editor and AI tooling
23. A complete automation program
24. Design habits
25. Current boundaries and known gotchas

---

## 1. Why Lume

Automation often begins as a few shell commands. Then it acquires configuration,
loops, subprocesses, JSON, error handling, and data passed between functions.
At that point, text-typed scripts become hard to change safely.

Python solves the size problem but normally moves many mistakes to runtime.
Large general-purpose languages provide stronger checking, but their projects
and toolchains can feel heavy for a small operational task.

Lume occupies the space between them:

- concise enough for scripts;
- statically checked before execution;
- structured around records, enums, lists, maps, and results;
- compiled to compact, validated bytecode;
- intentionally small enough to describe to an AI model;
- designed around a 10,000-source-lines-per-second compilation target.

See [`BENCHMARKS.md`](../BENCHMARKS.md) for actual, dated measurements —
treat any single number as a local measurement on one machine, not a
universal promise.

## 2. Your first program

Create `hello.lume`:

```lume
fn main(args: [str]) -> int {
  var name = "world"
  if list.len(args) > 0 {
    name = list.get(args, 0)
  }
  print("hello, " + name)
  return 0
}
```

Run it:

```text
lume run hello.lume Ada
```

Every program has a `main` function. It receives command-line arguments as a
list of strings and returns an integer exit code. Zero conventionally means
success.

The full command surface:

```text
lume run <file.lume> [args...]
lume check <file.lume>
lume tokens <file.lume>
lume bytecode <file.lume>
lume build <file.lume> [output.lbc]
lume exec <file.lbc>
lume benchmark <file.lume> [iterations]
lume test <file.lume|dir> [--filter text] [--ignore names]
lume fmt <file.lume> [--check]
lume install <dir>
lume lsp
lume api
lume ai-reference
```

Use `check` in fast feedback loops: it validates a program without running its
effects. Add `--json` to `check`/`fmt --check`/`test` for machine-readable
output (see section 20).

## 3. Values, bindings, and expressions

Lume's core scalar types are `int`, `str`, and `bool`:

```lume
let retries = 3
let service = "billing"
let enabled = true
```

`let` creates an immutable binding. Prefer it by default. Use `var` only when a
loop or state transition requires reassignment:

```lume
var total = 0
total = total + 1
```

**`let`/`var` have no type-annotation syntax at all** — `let name = expr` is
the only form; `let name: Type = expr` is a compile error (`E0204 expected
=`). A binding's type is always inferred from its initializer. This matters
for an empty collection literal: `var items = []` infers an unusable
placeholder element type that later assignments will reject — seed it with a
real first element instead (`var items = [firstValue]`, then `list.push` the
rest), the same way `map.new()` alone doesn't carry concrete key/value types
until a real `map.set` call establishes them.

The compiler rejects assignment to `let`, inconsistent reassignment, unknown
names, invalid operands, and calls with the wrong arity.

Arithmetic and comparison operators are deliberately familiar:

```lume
let cost = count * price
let ready = retries < 3
let same = left == right
```

The full operator set is `+ - * / % == != < <= > >=`, plus the boolean
keyword-operators `and`/`or`/`not` (section 4) — `and`/`or` genuinely
short-circuit, so `a and b()` never calls `b()` when `a` is already
`false`. String concatenation overloads `+`:

```lume
let message = "service=" + service
```

**There is no `int`-to-`str` interpolation or formatting operator.** Convert
a number to text explicitly with `str.from_int(n)`:

```lume
let message = "retry " + str.from_int(retries) + " of 3"
```

There is no string-interpolation syntax (`"{expr}"` is printed completely
literally, braces and all — it is not a template), and **there is no `??`
null-coalescing operator** — that is Certo syntax (the separate language
this bootstrap compiler is itself written in), not Lume. Get a value out of
an `Option<T>` or a builtin's `Result`-shaped return with `match` or a
plain `if`/`var`, as shown in sections 6 and 10.

## 4. Control flow — and what Lume deliberately leaves out

Conditions must be boolean:

```lume
if enabled {
  print("enabled")
} else {
  print("disabled")
}
```

Loops are explicit and predictable:

```lume
var index = 0
while index < list.len(items) {
  print(list.get(items, index))
  index = index + 1
}
```

**There is no `for` loop at all — not a range loop, and not a `for x in
list` iteration loop either.** `while` is the only loop construct. Every
example in this book that walks a list uses a manually incremented index:

```lume
var index = 0
while index < list.len(entries) {
  print(list.get(entries, index))
  index = index + 1
}
```

There is also no `break`/`continue` — express early exit with a boolean
flag checked in the loop condition.

`if`/`else` can also be used directly as an expression, not just a
statement — both branches must produce the same type, and `else` is
required (every path must produce a value):

```lume
let label = if score >= 90 { "A" } else { "B" }
print(if count > 0 { "found " + str.from_int(count) } else { "none" })
```

**One real, easy-to-trip gotcha, worth stating plainly**: an
if-expression only works in statement context — inside a closure body
(the `fn(x) -> T => ...` form passed to `list.map`/`filter`/`find`/
`fold`), it compiles fine but fails at *runtime* with "callback uses
unsupported operation", exactly like `match` already does inside a
closure (section 6). Write a small helper function with an early
`return` in each branch instead when the value is needed inside a
closure:

```lume
fn clamp_or_zero(value: int, limit: int) -> int {
  if value > limit {
    return limit
  }
  return value
}
```

- **`and`/`or`/`not` are keywords, not symbols** — there is no `&&`/`||`/`!`
  for boolean logic (`!` is reserved for `Result`/`Option` propagation, see
  section 10). `not` binds tighter than `and`, which binds tighter than
  `or` — ordinary precedence:

  ```lume
  if a and b {
    // ...
  }

  if not ready or retries > 3 {
    // ...
  }
  ```

  `and`/`or` genuinely short-circuit: the right operand is never evaluated
  once the left already determines the result (`false and expensive()`
  never calls `expensive()`; same for `true or expensive()`). Both operands
  of `and`/`or`, and the operand of `not`, must be `bool` — there is no
  truthiness.

The checker prevents integers, strings, or records from being used as
accidental conditions.

## 5. Functions and recursion

Parameters and return values have declared types:

```lume
fn add(left: int, right: int) -> int {
  return left + right
}
```

Recursive functions are supported:

```lume
fn factorial(value: int) -> int {
  if value <= 1 {
    return 1
  }
  return value * factorial(value - 1)
}
```

A bad argument or return type is a compile error, not an unpleasant discovery
halfway through an automation run.

## 6. Lists and transformations

List literals are homogeneous and infer their element type:

```lume
let ports = [5432, 5433, 5434]
let names = ["api", "worker", "scheduler"]
```

Nested list types are written `[[int]]`, `[[str]]`, and so on.

The basic immutable list operations are:

```lume
list.len(values)
list.get(values, index)
list.push(values, new_value)
```

`list.push` returns a new list; it does not change the original. There is no
`list.set`/update-at-index, no removal function (`pop`/`remove`), and no
range-check that returns an `Option` — `list.get` on an out-of-range index is
a runtime failure, not a safe `None`.

Typed transformations take a named function reference (`&name`) or an inline
closure:

```lume
fn double(value: int) -> int { return value * 2 }
fn even(value: int) -> bool { return value % 2 == 0 }
fn add(total: int, value: int) -> int { return total + value }

let values = [1, 2, 3, 4]
let doubled = list.map(values, &double)
let evens = list.filter(values, &even)
let first_even = list.find(values, &even)     // Option<int>
let total = list.fold(values, 0, &add)
```

Callback input and output types are checked at compile time. Inline closures
use `fn(parameter: type) -> return_type => expression` and may capture
immutable (`let`) bindings by value — capturing a `var` is rejected:

```lume
let offset = 10
let shifted = list.map(values, fn(value: int) -> int => value + offset)
```

A closure or `&name` reference works only as the *direct, inline* argument to
`list.map`/`filter`/`find`/`fold`/`map.map`/`filter`/`fold` — neither is a
general first-class value; a closure cannot be bound to a `let` and called
later. `match` is not supported anywhere in a closure's reachable call graph
(it fails at runtime with "callback uses unsupported operation" if it is) —
write logic that needs to pattern-match an enum as an ordinary function
called directly instead of inside a callback.

## 7. Records and immutable updates

Records give names and types to related data:

```lume
type Database {
  host: str
  port: int
  secure: bool
}

let database = Database(host: "db.internal", port: 5432, secure: true)
print(database.host)
```

Construction requires every field exactly once. Unknown fields, missing
fields, duplicates, and incorrect values are rejected.

Use `with` to create a changed copy:

```lume
let local = database with { host: "localhost", secure: false }
```

The original remains unchanged. Updates may be nested:

```lume
type Preferences { theme: str }
type User { name: str, preferences: Preferences }

let darker = user with {
  preferences: user.preferences with { theme: "dark" }
}
```

## 8. Enums and exhaustive matching

An enum describes a closed set of states. Variants may carry typed payloads:

```lume
enum JobState {
  waiting
  running(attempt: int)
  completed(code: int)
  failed(message: str)
}

let state = JobState.running(attempt: 2)
```

`match` is an expression and evaluates only its selected arm:

```lume
fn describe(state: JobState) -> str {
  return match state {
    waiting => "waiting"
    running(attempt) => "running"
    completed(code) => "completed"
    failed(message) => message
  }
}
```

Every variant must appear exactly once, and every arm must produce a
compatible type. Non-enum subjects, impossible variants, duplicate arms,
non-exhaustive matches, and inconsistent arm result types are compile
errors. Payload names exist only inside their arm and receive their types
from the enum declaration; a bare arm such as `completed => ...` explicitly
ignores its payload.

## 9. Generics, constraints, and protocols

Generics let one definition retain precise types across many uses:

```lume
fn identity<T>(value: T) -> T {
  return value
}

let number = identity(42)
let label = identity("primary")
```

Generic records and enums use the same parameter syntax:

```lume
type Box<T> { value: T }
```

The compiler infers substitutions from call and constructor arguments; a
generic call site or constructor is not a general first-class value either.

Constrain a generic function with one of four built-in markers: `Eq`, `Ord`,
`Number`, or `Text`:

```lume
fn keep_number<T: Number>(value: T) -> T {
  return value
}
```

`Number` accepts `int`; `Text` accepts `str` (and allows `+` inside the
constrained function's own body); `Eq`/`Ord` accept `int`/`str`/`bool`
natively, and any record or enum type with an explicit `impl`:

```lume
type Point { x: int, y: int }

impl Eq for Point {}
```

An `impl Eq for X {}` (empty body — this is opt-in *marking*, not derivation)
makes `X` usable anywhere `T: Eq` is required, including as a `Map<K, V>`
key. `Ord` needs a real method body for a compound type, since ordering isn't
structurally obvious the way equality is:

```lume
impl Ord for Point {
  fn compare(a: Point, b: Point) -> int {
    if a.x != b.x { return a.x - b.x }
    return a.y - b.y
  }
}
```

Once implemented, `<`/`<=`/`>`/`>=` (and `==`/`!=` via `Eq`) work directly on
values of that type inside any function whose own generic parameter is
constrained by the matching marker.

Projects can also declare their own protocols with required methods:

```lume
protocol Named {
  fn name(value: Self) -> str
}

impl Named for User {
  fn name(value: User) -> str {
    return value.name
  }
}

fn keep_named<T: Named>(value: T) -> T {
  return value
}
```

Protocol methods compile to concrete functions and are called with qualified
static syntax (`User.name(user)`) — there is no runtime method lookup or
dynamic dispatch. The compiler rejects a missing, extra, duplicate, or
incorrectly typed method, an unknown protocol, or a duplicate implementation
for the same type.

## 10. Option and Result

`Option<T>` and `Result<T, E>` are always available, without any
declaration. `Option<T>` is a single, consistent enum: every function that
produces one (`list.find`, `map.get`, or a function you declare yourself
with `-> Option<T>`) can be read the same way, with `match`:

```lume
fn even(value: int) -> bool { return value % 2 == 0 }

let selected = list.find([1, 3, 4], &even)      // Option<int>
let display = match selected {
  Some(value) => value
  None => 0
}
```

**`Result` is not this simple — there are two separate, non-interchangeable
"Result" conventions in the current bootstrap, confirmed by direct testing
against the real compiler, not documented anywhere else in this
repository.** Getting this wrong produces confusing type-mismatch errors
rather than a clear diagnostic, so it is worth learning as one fact rather
than debugging by trial and error.

**World 1 — the `Result` enum**, for a function *you* write and construct
by hand:

```lume
fn validate(port: int) -> Result<int, str> {
  if port > 0 {
    return Result.Ok(value: port)
  }
  return Result.Err(error: "port must be positive")
}

print(match validate(5432) { Ok(value) => value, Err(message) => 0 })
```

Read this kind with `match { Ok(x) => ..., Err(e) => ... }`, or with `?`/`!`
to propagate out of another function that also declares `-> Result<T, E>`
(capitalized):

```lume
fn checked_port() -> Result<int, str> {
  let port = validate(5432)?
  return Result.Ok(value: port)
}
```

**World 2 — the lowercase `result<T, E>` builtins produce**: `fs.try_read_text`/
`try_write_text`, `dir.list`, `dir.walk`, every `http.*` request function,
`fs.read_bytes`, and `Type.from_json`/`EnumName.from_json` (section 12) all
return this second kind, not the `Result` enum above — confirmed directly:
a value from any of these **cannot be matched with `match { Ok(...) =>
..., Err(...) => ... }`** (`E0650 match requires an enum`) and **cannot be
returned from a function declared `-> Result<T, E>`** (capitalized —
`E0618 type mismatch`), even though both "look like a Result." Read and
build this kind exclusively through the plain `result.*` helper functions,
and declare a wrapping function's own return type in **lowercase**:

```lume
result.ok(value)          // wraps value as this kind's own Ok
result.err(message)       // wraps message as this kind's own Err
result.is_ok(outcome)     // -> bool
result.value(outcome)     // unwraps Ok, panics on Err
result.error(outcome)     // unwraps Err, panics on Ok
```

`?`/`!` still work for propagation, but only inside a function whose own
declared return type is the matching lowercase `result<T, E>`:

```lume
type AppConfig { name: str }

fn load_config(path: str) -> result<AppConfig, str> {
  let source = fs.try_read_text(path)?
  return AppConfig.from_json(source)
}

fn main(args: [str]) -> int {
  let loaded = load_config("app.json")
  if result.is_ok(loaded) {
    let config = result.value(loaded)
    print(config.name)
  } else {
    eprint(result.error(loaded))
  }
  return 0
}
```

**The practical rule**: if the value came from `fs.*`/`dir.*`/`http.*`/
`.from_json(...)` at any point in its history, treat it as world 2 for the
rest of its life — read it only with `result.*`, and if you wrap it in your
own function, declare that function's return type in lowercase
`result<T, E>` too. If you constructed it yourself with `Result.Ok(...)`/
`Result.Err(...)`, it's world 1 — use `match`. Never mix the two: neither
`result.is_ok` on a `Result.Ok(...)`-constructed value nor `match` on a
builtin's return will type-check.

## 11. Typed maps

`Map<K, V>` is a built-in key/value collection, constructed and read through
`map.*` builtins rather than literal syntax. Keys are restricted to
`int`/`str`/`bool` — or any record/enum type with an explicit `impl Eq`:

```lume
fn sum(total: int, value: int) -> int { return total + value }

let empty = map.new()
let scores = map.set(map.set(empty, "Ada", 92), "Grace", 98)
print(map.has(scores, "Ada"))
print(map.len(scores))
print(match map.get(scores, "Ada") { Some(score) => score, None => -1 })
print(list.len(map.keys(scores)))

let cleared = map.remove(scores, "Ada")
let raised = map.map(scores, fn(value: int) -> int => value + 1)
let passing = map.filter(scores, fn(value: int) -> bool => value >= 95)
let total = map.fold(scores, 0, &sum)
```

Like `list.push`, every `map.*` mutation returns a new map. `map.map`/
`filter` callbacks take the value only (`(V) -> ...`); keys pass through
unchanged. There is no map literal syntax and no `(key, value)`
two-parameter callback shape.

A bare `map.new()` alone does not carry a concrete key/value type — passing
it straight into something that requires `Map<str, str>` before any real
`map.set` establishes those types can fail to type-check. Establish the
types with a real `set`/`get` first, or build-then-remove for a genuinely
empty typed map:

```lume
let headers = map.remove(map.set(map.new(), "placeholder", "value"), "placeholder")
```

## 12. JSON: encoding and decoding

Decode JSON directly into a record schema — `Type.from_json(text)` returns
the lowercase `result<Type, str>` builtin convention from section 10, not
the `Result` enum, so read it with `result.*`, never `match`:

```lume
type User { name: str, active: bool }

let decoded = User.from_json(text)
if result.is_ok(decoded) {
  let user = result.value(decoded)
  print(user.name)
} else {
  eprint(result.error(decoded))
}
```

(Bind the call's result to a `let` before accessing a field on it, as
above — a function call's return value cannot have a field chained directly
onto it, e.g. `result.value(decoded).name` is a syntax error, `expected
)`.)

Decoding checks schemas recursively, including nested records, lists, and
enums. Errors contain the failing field path (`User.address.city must be
str`). Missing, unknown, and incorrectly typed fields are all rejected.

`EnumName.from_json(text)` decodes the same `{"variant": "Name", ...}` shape
`json.encode` (below) produces, matching an unknown variant or a missing/
mistyped payload field with its own clear error.

`json.encode(value) -> result<str, str>` (section 10's builtin convention
again — unwrap with `result.value`, don't `print` it directly, or you'll
see its raw internal tagging rather than the JSON text) goes the other
direction and needs no schema — every value already carries its own
runtime type tag, so it works on any `str`/`int`/`bool`/record/list/enum,
recursively:

```lume
print(result.value(json.encode(user)))                 // {"name":"Ada","active":true}
print(result.value(json.encode(State.waiting())))       // {"variant":"waiting"}
print(result.value(json.encode(State.done(code: 7))))   // {"variant":"done","code":7}
print(result.value(json.encode(Option.Some(value: 1)))) // {"variant":"Some","value":1}
```

`json.valid(text) -> bool` and `json.get(text, key) -> str` (a scalar-only
raw-field reader, distinct from schema-checked `from_json`) round out the
`json.*` group.

## 13. Files and paths

Core file operations:

```lume
fs.exists(path)                 // -> bool
fs.read_text(path)              // -> str (fails the program if missing)
fs.write_text(path, content)    // -> bool
fs.try_read_text(path)          // -> result<str, str> (section 10's builtin convention)
fs.try_write_text(path, content)// -> bool
fs.read_bytes(path)             // -> result<bytes, str>
fs.write_bytes(path, data)      // -> bool
```

Prefer the `try_` forms when failure is expected and should remain data; use
the plain forms when failure should stop the program. Read a `try_`/
`read_bytes` outcome with `result.is_ok`/`result.value`/`result.error`
(never `match`) — see section 10.

`path.*` is pure string manipulation, portable across `/` and `\`
separators — no filesystem access:

```lume
let dir = path.join("reports", "2026")
print(path.basename("reports/2026/summary.csv"))  // summary.csv
print(path.dirname("reports/2026/summary.csv"))   // reports/2026
print(path.stem("reports/2026/summary.csv"))      // summary
print(match path.extension("reports/2026/summary.csv") {
  Some(ext) => ext
  None => "none"
})                                                 // csv
```

`path.extension` returns `None` for a path with no dot, or a leading-dot
name like `.gitignore`.

`dir.list(path) -> result<[str], str>` lists one directory level (names
only, unsorted). `dir.walk(path, maxDepth) -> result<[str], str>` recurses:
entries are *full paths, files only* (a subdirectory is recursed into, never
included itself), unsorted; `maxDepth` of `0` means no recursion at all
(only `path`'s own files); an unreadable subdirectory partway through is
silently skipped rather than failing the whole call:

```lume
let found = dir.walk("reports", 8)
if result.is_ok(found) {
  let entries = result.value(found)
  var index = 0
  while index < list.len(entries) {
    print(list.get(entries, index))
    index = index + 1
  }
}
```

## 14. Processes and environment values

Run a process with an explicit executable and list of arguments:

```lume
let outcome = process.run("git", ["status", "--short"])
if process.ok(outcome) {
  print(process.stdout(outcome))
} else {
  eprint(process.stderr(outcome))
}
```

Read its exit code, stdout, stderr, and success flag with `process.code`/
`process.stdout`/`process.stderr`/`process.ok`. Arguments are always a list,
never an interpolated command string — this keeps spaces and quoting
predictable.

Three richer variants, all returning the same `process` result:

```lume
process.run_with_input(exe, args, input)          // pipes input to stdin
process.run_with_env(exe, args, envMap)           // Map<str,str> overrides, restored after
process.run_with_options(exe, args, workingDir, timeoutMs)
```

`process.run_with_options`'s `workingDir` of `""` means "don't change
directory"; `timeoutMs <= 0` means no timeout. A timed-out process is killed
and reports `process.code(result) == -1` — the same value a failed-to-spawn
process reports, since the underlying result has no separate "timed out"
flag; don't rely on `-1` alone to distinguish the two cases.

Read environment values with:

```lume
env.get(name)      // -> str
env.has(name)      // -> bool
env.set(name, value)   // -> bool
env.unset(name)        // -> bool
```

## 15. HTTP requests

`http.get(url)`/`http.delete(url)` return `result<http, str>` (section 10's
builtin convention — read with `result.*`, never `match`):

```lume
let outcome = http.get("http://example.com")
if result.is_ok(outcome) {
  let response = result.value(outcome)
  print(http.status(response))
  print(http.ok(response))
} else {
  eprint(result.error(outcome))
}
```

`http.post(url, body, content_type)`/`http.put(url, body, content_type)`
send a fixed-`Content-Type` body. `http.request(method, url, headers, body)`
(`headers: Map<str, str>`) sends any method with arbitrary headers — the
only one of these that can send `Authorization` or anything beyond a fixed
`Content-Type`. `http.request_bytes(method, url, headers, data)` mirrors it
with a `bytes` body, paired with `http.body_bytes(response) -> bytes`.

Read a response with `http.status`/`http.body`/`http.content_type`/
`http.ok`/`http.truncated`.

All six of the functions above are bounded at a fixed 10 MiB response size —
checked *at request time* (the client stops reading once the limit is hit,
not after downloading further), converting an oversized response into `Err`.
For a caller-chosen limit that does *not* auto-error, use
`http.request_with_limit(method, url, headers, body, maxBytes) ->
result<http, str>` (`maxBytes <= 0` means unlimited) and check
`http.truncated(response) -> bool` yourself:

```lume
let headers = map.remove(map.set(map.new(), "x", "y"), "x")  // empty Map<str,str>
let outcome = http.request_with_limit("GET", url, headers, "", 1024)
if result.is_ok(outcome) {
  let response = result.value(outcome)
  if http.truncated(response) {
    print("response was cut off at 1024 bytes")
  }
}
```

HTTP is Windows-only today — the underlying client is a stub on other
platforms that aborts the process rather than returning an `Err`.

## 16. Bytes

`bytes` is a type distinct from `str`, but represented identically at
runtime — a deliberate scope reduction, not a NUL-safe binary type. Content
with an embedded NUL byte truncates at the NUL on round-trip.

```lume
bytes.from_str(text) -> bytes
bytes.to_str(data) -> str
bytes.length(data) -> int
```

`fs.read_bytes`/`fs.write_bytes` and `http.request_bytes`/
`http.body_bytes` mirror the `str` file/HTTP APIs with a `bytes` payload.

## 17. Time and duration

```lume
time.now() -> int                              // Unix epoch seconds
time.to_iso(seconds) -> str                    // UTC ISO-8601
time.year/month/day/hour/minute/second(seconds) -> int   // UTC calendar components
time.format(seconds, pattern) -> str           // strftime-style, UTC
time.in_timezone(seconds, zone) -> result<str, str>          // section 10's builtin convention
time.format_in_timezone(seconds, pattern, zone) -> result<str, str>
```

`pattern` accepts the host `strftime`'s directives (`%Y`, `%m`, `%d`, `%H`,
`%M`, `%S`, `%A`, `%B`, and so on). `zone` is an IANA name
(`"America/New_York"`); an unrecognized name is `Err`, not a crash. Avoid
`%Z`/`%z` inside `format_in_timezone`'s pattern — those two directives read
the *host's own* configured timezone, not `zone`, so they cannot reflect an
arbitrary zone correctly; use `time.in_timezone`'s own numeric offset
instead.

```lume
duration.seconds/minutes/hours/days(n) -> int
```

These are plain `int`-returning functions, the same representation
`time.now()` uses — not a distinct `Duration` type with its own arithmetic.
`time.now() + duration.minutes(5)` reads as what it means instead of a magic
`300`.

## 18. Modules

Split related functions into files and import them with `use`. Module paths
are dotted and resolve to files relative to the importing file:

`modules/math.lume`:

```lume
pub fn math.square(value: int) -> int {
  return value * value
}
```

`main.lume`:

```lume
use modules.math

fn main(args: [str]) -> int {
  print(math.square(9))
  return 0
}
```

Imports are loaded recursively, once per graph. Missing modules, import
cycles, and duplicate function symbols are compile errors. The `.lbc`
bytecode cache hashes the combined dependency graph, so changing any
imported file invalidates the root cache.

There is no bare `use fs`/`use json` for the builtin standard library —
every builtin (`fs.*`, `json.*`, `str.*`, and so on) is always available
without any `use` statement at all; `use` is only for a project's own
modules.

## 19. Packages

A directory becomes a package with a `lume.json` manifest:

```json
{ "name": "mathutils", "version": "0.1.0" }
```

Another project depends on it by declaring a local relative path in its own
manifest:

```json
{
  "name": "app",
  "version": "0.1.0",
  "dependencies": [{ "name": "mathutils", "path": "../mathutils" }]
}
```

`lume install <dir>` resolves dependencies once (including transitively —
`mathutils` can declare its own dependencies, and `app` picks them up
automatically) and writes `lume.lock.json`, the file `use` resolution
actually reads:

```text
lume install examples\packages\app
lume run examples\packages\app\app.lume
```

`use mathutils.ops` then resolves through the lock file into `mathutils`'s
directory instead of a local relative path; everything else about `use`
works the same as an ordinary in-project module. A project with no
`lume.json`/`lume.lock.json` sees no change in behavior at all. A dependency
cycle across `lume.json` files is `E0709`; the same package name resolving
to two different locations is `E0708`. There is no real version-range
resolution or registry yet — `version` is recorded but not checked against
anything.

**Dependencies are isolated per package, not shared across the whole
resolved tree.** If `app` depends on `mathutils`, and `mathutils` depends on
`formatting`, `app` can call into `mathutils` freely — but `app` cannot
`use formatting` directly unless it *also* declares `formatting` as its own
dependency. This matters even when it looks like it should "just work":
`formatting` genuinely exists somewhere in `app`'s resolved tree, but
`app`'s own manifest never asked for it, so it isn't visible to `app`'s own
files. Declare exactly what you use, in the package that uses it — the same
rule real package managers enforce, and for the same reason: a package's
own `lume.json` is the only thing that reliably tells you what it needs.

## 20. Testing

A native test has a descriptive string name and a block of expectations:

```lume
test "calculates the total" {
  expect.equal(list.fold([1, 2, 3], 0, &add), 6)
}
```

Assertions: `expect.equal`, `expect.true`, `expect.ok`, `expect.err`,
`expect.some`, plus process-output assertions for a captured
`process.run`-style result: `expect.exit_code`, `expect.stdout_contains`,
`expect.stderr_contains`.

A test body runs through the same restricted evaluator as a list-transform
callback (section 6) — `match` anywhere in its reachable call graph fails at
runtime; verify `match`-using logic by calling it from `main` and checking
output instead.

An optional timeout clause bounds a test against a runaway loop:

```lume
test "completes quickly", timeout: 50 {
  expect.true(true)
}
```

Run every test in one file:

```text
lume test tests.lume
```

Select tests with `--filter text` (matches against the full stable id, see
below — a bare name or a path fragment both work). Pass a directory instead
of a file to discover every `*_test.lume` file *recursively*, not just at
the top level (a fixed internal 32-level depth bound). Skip subdirectories
by name with `--ignore name1,name2` (e.g. `--ignore node_modules,.git`) — no
default ignore list; nothing is skipped unless you say so:

```text
lume test tests --ignore node_modules,.git
lume test tests --filter "tests/math_test.lume"
```

Add `--json` (in either order relative to `--filter`) for structured,
line-delimited JSON — for CI and editor integrations:

```text
lume test examples\native_tests.lume --json
```

```json
{"event":"test","id":"examples/native_tests.lume#adds two values","name":"adds two values","status":"pass","line":9,"message":""}
{"event":"summary","passed":1,"failed":0,"total":1}
```

Directory mode adds one `{"event":"file","path":"..."}` line per discovered
file. `id` is `<path>#<name>` exactly as the path was passed on the command
line — stable enough to disambiguate same-named tests across files and to
feed straight back into `--filter` for an exact rerun.

## 21. Building, bytecode, and performance

`lume run` maintains a content-hash-validated `.lbc` bytecode cache beside
the source; unchanged source skips lexing, parsing, validation, and
emission. Build and execute an artifact explicitly:

```text
lume build deploy.lume deploy.lbc
lume exec deploy.lbc
```

Truncated or corrupt bytecode is rejected rather than partially executed.
`.lbc` files are reproducible build products, ignored by Git.

Measure the in-process compiler and artifact decoder:

```text
lume benchmark deploy.lume 1000
```

See [`BENCHMARKS.md`](../BENCHMARKS.md) for the repository's own dated,
reproducible measurements and methodology, and for the acceptance gate a
feature must clear (no more than a 5% median clean-compile regression
without an offsetting benefit).

## 22. Editor and AI tooling

**Two separate pieces of editor support exist, at different levels of
depth — use whichever fits, and don't assume they behave identically:**

- **`lume lsp`** (built into the compiler itself) runs a diagnostics-only
  Language Server Protocol server over stdio (`Content-Length`-framed
  JSON-RPC, full-document sync). It handles `initialize`/`shutdown`/`exit`
  and publishes at most one real, compiler-verified diagnostic per file on
  `textDocument/didOpen`/`didChange`/`didClose` (`lume.cto`'s own compile
  pipeline reports only the first error it finds, so a file with multiple
  problems only ever shows the first until that pipeline is widened to a
  real diagnostic list — a known, deliberate scope boundary). It does not
  provide completion, hover, or go-to-definition.
- **`lsp\lume-lsp.ps1`** (a separate PowerShell script, `lsp/README.md`)
  wraps `lume check <tempfile> --json` for the same one-diagnostic-per-file
  behavior, and *additionally* provides:
  - **completion**: a small static keyword list plus every name in
    `ai/lume-api.json` — not scope- or type-aware; it always offers the
    same list regardless of context;
  - **hover**: shows a builtin's arity or "Lume keyword" for the exact word
    under the cursor, matched against the same static lists — no real type
    information;
  - **go-to-definition**: a same-document-only regex search for
    `fn <name>(` — it cannot jump across files;
  - **formatting**: a simple, independent brace-depth reindenter — **not**
    the same implementation as the compiler's own canonical `lume fmt`, and
    not guaranteed to agree with it on every input.

  Start it with `powershell.exe -File .\lsp\lume-lsp.ps1` (expects
  `dist\lume.exe`; pass `-Lume <path>` otherwise). Run `lsp\test.ps1` for
  its own smoke test.

For AI generation, two commands expose the language in compact forms:

```text
lume api            # machine-readable feature/builtin manifest (ai/lume-api.json)
lume ai-reference    # a compact, prose generation guide
```

Good prompts state input/output data shapes, permitted effects (files,
subprocesses, network), desired exit-code behavior, whether failures should
be returned or terminate execution, and concrete expected output — then ask
the model to run `lume check` before treating a draft as done. Static
diagnostics make repair local and specific; the gotchas in section 25 below
are exactly the kind of thing worth stating up front in a prompt, since they
are easy for a model to get wrong by analogy to more common languages.

## 23. A complete automation program

```lume
type CommandConfig { executable: str, arguments: [str] }
type AppConfig { name: str, command: CommandConfig }

fn load_config(path: str) -> result<AppConfig, str> {
  let source = fs.try_read_text(path)?
  return AppConfig.from_json(source)
}

fn main(args: [str]) -> int {
  var path = "app.json"
  if list.len(args) > 0 {
    path = list.get(args, 0)
  }
  let loaded = load_config(path)

  if result.is_ok(loaded) {
    let config = result.value(loaded)
    let completed = process.run(config.command.executable, config.command.arguments)
    if process.ok(completed) {
      print(str.trim(process.stdout(completed)))
      return 0
    } else {
      eprint(str.trim(process.stderr(completed)))
      return process.code(completed)
    }
  } else {
    eprint(result.error(loaded))
    return 1
  }
}
```

`load_config` returns the *lowercase* `result<AppConfig, str>` (section
10's builtin convention), not the capitalized `Result` enum, because it
propagates two builtin calls (`fs.try_read_text`, `AppConfig.from_json`)
that are already that kind — `?` only propagates between two functions in
the same world.

Example `app.json`:

```json
{
  "name": "repository status",
  "command": { "executable": "git", "arguments": ["status", "--short"] }
}
```

There is no command-string interpolation, configuration fields are checked,
JSON failures preserve their field paths, and every operational outcome
becomes an explicit exit code.

## 24. Design habits

1. Model external data with records immediately after reading it.
2. Model state transitions with enums rather than strings.
3. Keep bindings immutable unless a loop genuinely needs mutation.
4. Use `Result` for expected failure and `?` for short propagation paths.
5. Handle `Option` and enum values with exhaustive `match`.
6. Pass process arguments as lists, never as constructed shell command text.
7. Keep list callbacks small; use named functions or immutable-capture
   closures, and keep `match` out of them entirely.
8. Convert a number to text with `str.from_int`, not a workaround.
9. Use `and`/`or`/`not` directly for compound conditions; reach for a
   small boolean-returning helper function only once a condition needs
   more explanation than the operators alone can give it.
10. Put reusable logic in modules and effects near `main`.
11. Run `lume check` continuously and test both success and failure paths.
12. Measure compiler performance after expanding the language core.

## 25. Current boundaries and known gotchas

Real, current limitations — not aspirational roadmap items from other
documents in this repository:

- **`if`/`else` expressions don't work inside closures** — same
  restriction `match` already has there; use a helper function with
  early `return`s instead (section 4).
- **No `??` operator** — that is Certo syntax, not Lume's (section 3).
- **No `for` loop of any kind** — not a range loop, and not `for x in
  list` either. `while` with a manually managed index is the only loop
  construct (section 4). There is also no `break`/`continue`; use a
  boolean flag checked in the loop condition instead.
- **No `let`/`var` type annotations at all.** A binding's type always comes
  from its initializer (section 3).
- **Two separate, non-interchangeable `Result` conventions** — the
  capitalized `Result` enum you construct yourself vs. the lowercase
  `result<T, E>` every filesystem/directory/HTTP/JSON-decode builtin
  returns. Mixing them produces a type-mismatch or "match requires an
  enum" error rather than a clear diagnostic (section 10) — `Option<T>`
  has no such split.
- **A function call's return value cannot have a field accessed directly**
  — `f(x).field` is a syntax error (`expected )`); bind it to a `let`
  first, then access the field on that binding (section 12).
- **Closures and `&name` references are not first-class values** — usable
  only as the direct argument to a `list.*`/`map.*` transform, and cannot
  contain `match` anywhere in their reachable call graph (section 6).
- **`Ord` has no automatic derivation for compound types** — implement
  `compare(a, b) -> int` by hand (section 9).
- **`Map<K, V>` keys are limited** to `int`/`str`/`bool`, or a record/enum
  with an explicit `impl Eq` (section 11).
- **JSON decoding into an enum *field* inside a record is still not
  supported** — only decoding a top-level enum value directly
  (`EnumName.from_json`) works; a record containing an enum field cannot
  currently round-trip through `from_json` for that field.
- **`bytes` is not NUL-safe** — it is represented identically to `str` at
  runtime, so an embedded NUL byte truncates content on round-trip
  (section 16).
- **HTTP is Windows-only** — a stub on other platforms aborts the process
  rather than returning `Err` (section 15).
- **A timed-out process and a failed-to-spawn process both report
  `process.code == -1`** — there is no separate signal to tell them apart
  (section 14).
- **Compile diagnostics are single-error**: the whole compile pipeline
  reports only the first problem it finds in a file, never a list — this
  is why `lume lsp`/`lsp/lume-lsp.ps1` can only ever publish one diagnostic
  per file too.
- **A compact standard library, not a package ecosystem** — no registry,
  no semver-range resolution (section 19); local-path dependencies only.

These are useful constraints when choosing Lume, not defects to work around
by reaching for another language mid-task: use Lume for typed automation,
data transformation, command orchestration, configuration handling, and
compact tools where fast, predictable checking matters more than a large
library ecosystem or unrestricted expressiveness.

---

## Closing: fast is a workflow

Lume's speed is not only compiler throughput. It is the speed of discovering
a mistake before a deployment starts, understanding a script months later,
generating a valid first draft with AI, and changing a data shape without
guessing which paths will break.

That is the promise behind "the fast one": a small language that turns the
edit, check, understand, and run loop into one short motion.
