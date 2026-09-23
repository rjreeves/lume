# Lume language specification — draft 0.1

> **Reconciliation note.** This draft originally described a target design
> before much of it existed. It has since been rewritten section by section
> against the actual bootstrap compiler (`src/lume.cto`), verified by
> compiling and running probe programs rather than by inspection alone.
> Anything below marked **not yet implemented** is real, aspirational syntax
> that will parse-error or type-error today — kept here as the roadmap,
> clearly separated from what a program can rely on now. Section 19 lists
> every such gap in one place, split from the durable, load-bearing design
> exclusions it used to be lumped together with.

## 1. Principles

The language follows five rules:

1. There is one obvious representation for common code.
2. A file can be compiled with bounded local analysis.
3. Hidden control flow is forbidden.
4. Failure and absence are visible in types.
5. Tool output is stable enough for machines to consume.

## 2. Source model

- UTF-8 source files use the `.lume` extension.
- Newlines terminate statements except inside `[]`, `()`, or `{}` - a list
  literal, a function call's or record/enum-variant construction's
  parenthesized argument list, and a `with`-update's field list all tolerate
  newlines between items. **The one exception: a closure's own parenthesized
  parameter list (`fn(x: int, y: int) -> int => ...`) must still stay on one
  line** - a bootstrap limitation, not a design choice.
- Blocks use braces and must be formatted with two-space indentation.
- Line comments start with `//`. Documentation comments start with `///`.
- Identifiers are ASCII `snake_case`. Types are `PascalCase`.
- The formatter defines the only canonical layout (`lume fmt`, `lume fmt
  --check`).

## 3. Lexical grammar

```text
identifier  := [A-Za-z_][A-Za-z0-9_]*
int         := 0 | [1-9][0-9_]*
float       := int '.' [0-9_]+
string      := '"' character* '"'
comment     := '//' character* newline
```

Strings support `\n`, `\r`, `\t`, `\\`, `\"`, and Unicode escapes. **String
interpolation (`"hello, {name}"`) is not yet implemented** — build strings
with `+` concatenation instead. Raw backtick strings are not yet implemented
either.

A dotted call target (`list.get`, `str.upper`, `User.from_json`,
`math.square`) lexes as a single name token when immediately followed by
`(`. This is how the standard library's `noun.verb` calls and a module's
qualified function names are recognized — it is a lexer special case, not
general postfix `.` chaining (see §8).

## 4. Built-in types

```text
bool int float str bytes
[T]             list
Map<K, V>       key/value map; K is int/str/bool, or any record/enum
                type with `impl Eq for K {}` (see §6)
Option<T>       some T or none, spelled `Some`/`None`
Result<T, E>    ok T or err E, spelled `Ok`/`Err`
T ! E           sugar for a function's return type only; see §9
fn(A, B) -> C   the parameter type of a callback slot (see §12)
```

Integers are signed 64-bit. Floats are IEEE-754 binary64. `bytes` is a
type distinct from `str` at the type-checker level, but — as a
deliberate, documented scope reduction (see §11) — it does not carry
arbitrary binary content: an embedded NUL byte truncates on round-trip.

**Not yet implemented:** `unit`/`never` as usable types, and the
`T?` postfix sugar for `Option<T>` — write `Option<T>` explicitly. There
are no implicit conversions, but explicit ones exist both directions:
`str.from_int(n: int) -> str` and `str.to_int(text: str) -> Result<int,
str>` (§11) — a program that needs to turn a number into displayable
text, or parse a numeric string back into an `int`, has a real function
for it; `print`/`eprint` accepting any scalar directly is a separate,
additional convenience, not the only option.

## 5. Bindings

```lume
let name = "Ada"       // immutable; type inferred from the initializer
var retries = 3        // mutable
retries = retries - 1
```

**`let`/`var` do not accept a type annotation in the bootstrap** — `let
port: int = 5432` is a parse error today; the type is always inferred from
the initializer. This means an empty list literal (`[]`) has no element
type of its own: `var items = []` infers `[any]` and can never successfully
be assigned a concrete list afterward. Give it a home by returning it from
a function whose declared return type supplies the element type instead:

```lume
fn empty_tasks() -> [Task] {
  return []
}
```

Bindings cannot be shadowed in the same function. A variable must be
definitely initialized before use.

## 6. Functions

```lume
fn add(a: int, b: int) -> int {
  return a + b
}
```

Parameter and return types are mandatory. Functions are not overloaded.
Calls are positional only — there are no default or named arguments for
plain function calls (named arguments exist only for record/enum
construction, §8).

The entry point is `fn main(args: [str]) -> int`. Top-level executable
statements are forbidden.

### Generics

Functions, records, and enums accept type parameters, inferred at the call
site. This is fully implemented — despite §19 of an earlier draft of this
document still listing "user-defined generics" as excluded from v0.1:

```lume
type Box<T> { value: T }

fn identity<T>(value: T) -> T {
  return value
}
```

A type parameter may be constrained to one of four built-in marker
protocols (`Eq`, `Ord`, `Number`, `Text`), or to a user-declared marker
protocol implemented for a specific type:

```lume
fn keep_ordered<T: Ord>(value: T) -> T {
  return value
}

protocol Named {}

type User { name: str }

impl Named for User {}

fn keep_named<T: Named>(value: T) -> T {
  return value
}
```

A `protocol` body and its `impl ... for ...` body must both be empty — these
are compile-time markers only, with no methods and no dynamic dispatch, not
an interface/trait system. Constraints are validated after call-site
inference; a generic function compiles once to a type-erased runtime
representation rather than being specialized per concrete type.

`Eq` is additionally satisfiable by any record or enum type through the
same `impl` mechanism — `impl Eq for Point {}` — since `==`/`!=` already
compare any two values of the same declared type structurally. This is
an explicit opt-in, not automatic/derived conformance (implicit protocol
conformance is a non-goal of the core language, see `ROADMAP.md`); a
record without the `impl` does not satisfy `T: Eq`, matching any other
marker protocol. `Ord` remains restricted to `int`/`str` — ordered
comparison (`<`, `<=`, `>`, `>=`) has no generic runtime implementation
for compound types yet, so `impl Ord for ...` is not accepted.

### Closures

An inline closure — `fn(params) -> ReturnType => expression` — may capture
an enclosing `let` binding by value; capturing a `var` binding is a compile
error, so a closure is a stable snapshot, never shared mutable state:

```lume
let offset = 10
let shifted = list.map(values, fn(value: int) -> int => value + offset)
```

**This is much narrower than "function values" sounds.** A closure (and a
plain `&name` function reference, §12) may currently only appear as the
direct, inline argument to `list.map`, `list.filter`, `list.find`, or
`list.fold`. It cannot be bound to a `let` and called later, passed to a
user-defined higher-order function, or stored in a record field — `let f =
fn(x: int) -> int => x + 1` type-checks, but the compiler then has no
record of `f` as a callable value, and `f(1)` fails with "unknown
function". Functions are not yet first class; see §12 for exactly what a
callback body may contain.

## 7. Control flow

```lume
if score >= 80 {
  print("pass")
} else {
  print("retry")
}

while ready == false {
  poll()
}
```

Conditions must be `bool`; Lume has no truthiness. **`for`/`in` loops,
`break`, and `continue` are not yet implemented** — express iteration with
`while` and an explicit index, or with `list.map`/`filter`/`find`/`fold`
(§12). Boolean composition uses the keywords `and`/`or`/`not`, not symbols
— **there is no `&&`, `||`, or `!` for boolean logic** (`!` is reserved for
`Result`/`Option` propagation, §9):

```lume
if ready and not stopped {
  poll()
}
```

`and`/`or` genuinely short-circuit (the right operand is never evaluated
once the left already determines the result); `not` binds tighter than
`and`, which binds tighter than `or`.

`if` and `while` are statements, not expressions — an `if` cannot appear on
the right-hand side of an assignment or as a match arm's body. `match` (§9)
is the only expression-valued branching construct.

## 8. Data types

```lume
type User {
  id: int
  name: str
  address: Address
  tags: [str]
}

enum Status {
  pending
  running(started_at: int)
  failed(message: str)
  done
}
```

Records use named, order-independent construction (`User(name: "Ada", id:
1, ...)` — every field exactly once) and field access
(`user.address.city`). Enums use exhaustive `match` (§9). There are no
classes, inheritance, methods with hidden dispatch, or structural
subtyping.

Record- and enum-construction calls may span multiple lines like any other
argument list (§2). Field access chains directly onto any expression,
including a call's own result — `list.get(users, 0).name` works without
binding the call to a `let` first.

JSON decodes directly into a record via `Type.from_json(text)`, returning
the shorthand `str`-error result described in §9. Decoding supports `str`,
`int`, `bool`, nested records, enum fields (matched against a
`{"variant": "...", ...payload fields}` shape - the same one `json.encode`
below produces, so the pair round-trips), and lists of any of the above
recursively (including lists of records nested inside other records, and
records containing enum fields nested inside a list):

```lume
let decoded = Task.from_json("{\"name\":\"a\",\"status\":{\"variant\":\"pending\"}}")
```

`json.encode(value) -> Result<str, str>` encodes back the other direction,
supporting the same shapes decoding does — `str`, `int`, `bool`, nested
records, and lists, recursively — plus enum values, including `Option<T>`/
`Result<T,E>` (enums under the hood): an enum encodes as its variant name
under a `"variant"` key, with any payload fields flattened alongside it —
`State.done(code: 0)` becomes `{"variant":"done","code":0}`, and a
payload-free variant like `Option.None()` becomes `{"variant":"None"}`.
An enum nested inside a record field or list element is encoded the same
recursive way as anything else, and `Type.from_json` decodes that exact
shape back (§8) - `json.encode` then `Type.from_json` round-trips a
record containing enum fields correctly, verified live including a
payload-carrying variant and a list of records each with an enum field.
There is no schema or expected-type argument to `json.encode`: every
value already carries its own runtime type tag, so encoding a valid,
already-typechecked value cannot itself fail.

Records are updated immutably with `with`:

```lume
let updated = user with {
  active: true
  retries: user.retries + 1
}
```

## 9. Absence and errors

`Option<T>` has variants `Some(value: T)` / `None`, matched exhaustively
like any enum. There is no `T?` postfix sugar and no `??` operator (both
appear in older prose examples in this repo but are not implemented) —
write `Option<T>` and a `match` explicitly:

```lume
fn first<T>(items: [T]) -> Option<T> {
  if list.len(items) == 0 {
    return Option.None()
  }
  return Option.Some(value: list.get(items, 0))
}
```

### One `Result` type, two spellings

A function's return type can be written two ways, and both produce the
exact same runtime `Result<T, E>` value — freely interchangeable with
`match`, `result.*`, and each other.

**Shorthand, `str`-only errors** — a function declared with `T ! E` where
`E` is `str`:

```lume
fn upper_file(path: str) -> str ! str {
  let content = fs.try_read_text(path)?
  return result.ok(str.upper(content))
}
```

can be inspected either with the builtin functions `result.is_ok`,
`result.value`, and `result.error`:

```lume
let outcome = upper_file(path)
if result.is_ok(outcome) {
  print(result.value(outcome))
} else {
  eprint(result.error(outcome))
}
```

or with `match`, directly, no conversion needed:

```lume
print(match upper_file(path) {
  Ok(value) => value
  Err(error) => "failed: " + error
})
```

`result.ok`/`result.err` construct this shape, and `result.err` rejects any
error value that isn't `str`. Every I/O builtin that can fail
(`fs.try_read_text`, `fs.try_write_text`, `Type.from_json`) returns this
shape — and can be declared to return `Result<T, E>` directly instead of
`T ! E`, with no wrapping:

```lume
fn read_it(path: str) -> Result<str, str> {
  return fs.try_read_text(path)
}
```

**Fully generic errors** — declare the return type as `Result<T, E>` for
any `E`, including a custom enum, and construct it with `Result.Ok(value:
...)` / `Result.Err(error: ...)`:

```lume
enum ValidationError {
  empty_title(task_id: str)
}

fn validate(tasks: [Task]) -> Result<[Task], ValidationError> {
  if bad_id != "" {
    return Result.Err(error: ValidationError.empty_title(task_id: bad_id))
  }
  return Result.Ok(value: tasks)
}
```

This shape is inspected with `match { Ok(value) => ... Err(error) => ... }`
— and, since it's the same runtime value as the shorthand above,
`result.is_ok`/`result.value`/`result.error` accept it too:

```lume
let outcome = Result.Ok(value: 42)
print(if result.is_ok(outcome) { "ok" } else { "err" })
```

`result.to_result(x)` still exists as a validating identity (it errors on
a non-`Result` argument, same as before) — no existing call needs to
change, but a new one doesn't need it: a builtin's own result can already
be `match`ed or passed where a `Result<T, E>`-typed parameter is expected
without it.

```lume
fn describe(outcome: Result<str, str>) -> str {
  return match outcome {
    Ok(value) => "ok: " + value
    Err(error) => "err: " + error
  }
}

fn main(args: [str]) -> int {
  print(describe(fs.try_read_text(args.get(0))))
  return 0
}
```

`?` (and the compatibility spelling `!`) propagates an error out of the
current function immediately in both spellings, as long as the enclosing
function's own error type matches:

```lume
fn doubled() -> Result<int, str> {
  let value = successful()?
  return Result.Ok(value: value * 2)
}
```

There is no `try`/`catch`; failure is always a value.

## 10. Modules

One file is one module, loaded by textual concatenation, not by symbol
resolution. `use app.math` (relative to the *importing file's own
directory*) reads `app/math.lume` and splices its full source ahead of the
importing file before compilation, recursively, once per file in the
overall import graph:

```lume
use fs
use app.config
```

**`use ... as` aliasing is not implemented.** Imports must appear first and
cannot be dynamic; missing modules and import cycles are compile errors.

Because loading is pure text concatenation, **every record and enum name
must be unique across the entire reachable import graph** — there is no
per-file or per-module namespacing for types at all. Only a function may
carry a qualified-looking name (`math.square`, `stats.sum_of_squares`), and
that qualifier is nothing more than characters inside one literal
identifier token chosen by the author — it is a naming convention used
throughout this codebase, not a namespace the compiler resolves. `pub` is
written by convention on cross-file declarations but **is not currently
enforced** — a non-`pub` declaration is just as visible from another file in
the same graph.

A root file only needs to `use` the modules it actually needs reachable;
whether a submodule itself also `use`s its own dependencies only matters if
those dependencies aren't already reachable some other way from the root.

### Packages

A directory becomes a package by adding a `lume.json` manifest —
`{"name": str, "version": str, "dependencies": [{"name": str, "path":
str}, ...]}` (`dependencies` is a JSON array, not an object keyed by
name — deliberately, since `JsonValue.keys()` is not reliable on a
nested object obtained via `JsonValue.get()`, only on a top-level
parse; an array sidesteps it entirely via the already-proven
`JsonValue.length`/`JsonValue.atText` pair). `dependencies` entries
declare another package by a path relative to the manifest's own
directory — no registry, no version ranges yet, `version` fields are
declarative metadata only.

`lume install <dir>` is a separate step from ordinary compilation, per
this project's own constraint that package resolution must not happen
on every compile: it reads `<dir>/lume.json` and walks the full
dependency tree — a dependency's own `dependencies` are resolved too,
recursively — writing every reachable package into a single flat
`<dir>/lume.lock.json`, each entry's `path` already computed relative
to `<dir>` itself (not its immediate parent), so `use` resolution stays
a flat, single-level lookup regardless of nesting depth. A path
component is normalized (`..` segments collapsed) as it's computed, so
two routes to the same physical directory compare equal — without
that, a genuine cycle or a legitimate diamond dependency (two branches
depending on the same package) would produce different, incomparable
strings for the same location. Missing/malformed root manifest is
`E0705`; a dependency whose own manifest can't be read is `E0706`; the
same declared name resolving to two different locations is `E0708`; a
genuine dependency cycle is `E0709`; a lock file write failure is
`E0707`.

`use` resolution (`loadModule`) reads `lume.lock.json` once, at the
very start of loading the root file — never the manifest, and never
more than once per compile. For each `use` target, the segment before
the first `.` is checked against the lock file's dependency names
first; a match resolves the remainder into that dependency's directory
instead of the importing file's own directory. No match — no lock
file, no dot, or the name isn't declared — falls through to the
existing file-relative resolution, unchanged. A project with neither
file present behaves identically to before this existed.

## 11. Standard library

APIs follow `noun.verb` naming. The current, complete builtin surface
(regenerate with `lume api` after any compiler change) is:

```text
args.count()                  args.get(index)
fs.exists(path)                fs.read_text(path)
fs.write_text(path, text)      fs.try_read_text(path)
fs.try_write_text(path, text)
fs.read_bytes(path)             fs.write_bytes(path, data)
env.get(name)                  env.has(name)
env.set(name, value)            env.unset(name)
process.run(exe, args)         process.ok(result)
process.code(result)           process.stdout(result)
process.stderr(result)
process.run_with_input(exe, args, input)
process.run_with_env(exe, args, envMap)
process.run_with_options(exe, args, workingDir, timeoutMs)
http.get(url)                     http.delete(url)
http.post(url, body, content_type)
http.put(url, body, content_type)
http.request(method, url, headers, body)
http.request_with_limit(method, url, headers, body, maxBytes)
http.request_bytes(method, url, headers, data)
http.status(response)             http.body(response)
http.content_type(response)       http.ok(response)
http.body_bytes(response)         http.truncated(response)
bytes.from_str(text)            bytes.to_str(data)
bytes.length(data)
str.len(text)                  str.trim(text)
str.upper(text)                str.lower(text)
str.contains(text, part)       str.starts_with(text, prefix)
str.ends_with(text, suffix)
str.from_int(n)                str.to_int(text)
json.valid(text)                json.get(text, key)
json.encode(value)
path.join(a, b)                  path.basename(text)
path.dirname(text)               path.stem(text)
path.extension(text)             dir.list(path)
dir.walk(path, maxDepth)
time.now()                        time.to_iso(seconds)
time.year(seconds)                time.month(seconds)
time.day(seconds)                 time.hour(seconds)
time.minute(seconds)              time.second(seconds)
time.format(seconds, pattern)
time.in_timezone(seconds, zone)   time.format_in_timezone(seconds, pattern, zone)
duration.seconds(n)               duration.minutes(n)
duration.hours(n)                 duration.days(n)
Duration.of_seconds(n)            Duration.of_minutes(n)
Duration.of_hours(n)              Duration.of_days(n)
Duration.add(a, b)                Duration.sub(a, b)
Duration.scale(d, factor)         Duration.to_seconds(d)
list.len(values)                list.get(values, index)
list.push(values, item)         list.map/filter/find/fold(...)
map.new()                        map.len(m)
map.get(m, key)                  map.has(m, key)
map.set(m, key, value)           map.remove(m, key)
map.keys(m)                      map.values(m)
map.map/filter/fold(...)
result.ok(value)                result.err(message)
result.is_ok(result)            result.value(result)
result.error(result)             result.to_result(x)
expect.equal/true/ok/err/some(...)   (inside `test { ... }` blocks only, §13)
expect.exit_code/stdout_contains/stderr_contains(...)  (process assertions, §13)
fixture.temp_dir()               fixture.cleanup(path)
```

`map.map`/`map.filter`/`map.fold` mirror the `list.*` transforms exactly,
except the callback takes the value only (`(V) -> ...`) — keys pass
through unchanged for `map.map`/`map.filter`. There is no `(key, value)`
two-parameter callback shape yet.

`path.*` is pure string manipulation — no filesystem access, portable
across `/` and `\` separators. `path.stem` returns the last path
component with its extension removed (`path.stem("a/b/c.txt")` is `"c"`,
not `"a/b/c"`); `path.extension` returns `None` for a path with no dot or
a leading-dot name like `.gitignore` (no extension, not an empty one).

`dir.list(path) -> Result<[str], str>` lists one directory level — entry
names only (not full paths; combine with `path.join` when a full path is
needed), in whatever order the filesystem returns them (not sorted).
`dir.walk(path, maxDepth) -> Result<[str], str>` recurses up to
`maxDepth` levels, returning full paths (not just entry names) for every
file found - directories are descended into but not themselves included
in the result. `maxDepth` bounds a symlink loop; there is no true
inode-based cycle detection.

`time.now() -> int` returns the current time as Unix epoch seconds (UTC);
`time.to_iso(seconds) -> str` formats an epoch value as a fixed
`"YYYY-MM-DDTHH:MM:SSZ"` UTC string. `time.year`/`month`/`day`/`hour`/
`minute`/`second(seconds) -> int` read the UTC calendar components of
an epoch value (`time.year(1700000000)` is `2023`). `time.format(seconds,
pattern) -> str` formats an epoch value with a `strftime`-style pattern
(`%Y`, `%m`, `%d`, `%H`, `%M`, `%S`, `%A`, `%B`, and so on), also
evaluated against UTC; the underlying formatting call uses a fixed
256-byte buffer, so an unusually long pattern can silently truncate.
`time.in_timezone(seconds, zone) -> Result<str, str>` returns an ISO-8601
string with `zone`'s own numeric UTC offset (e.g. `+01:00`) instead of
`Z`, and `time.format_in_timezone(seconds, pattern, zone) -> Result<str,
str>` applies a `strftime`-style pattern to `zone`'s wall-clock time —
correctly zone- and DST-adjusted, not just UTC. `zone` is an IANA name
(`"America/New_York"`); an unrecognized name is `Err`, not a crash.
`%Z`/`%z` inside `format_in_timezone`'s pattern are unreliable — `strftime`
reads those from the host platform's own configured timezone, not
`zone` — so `time.in_timezone`'s numeric offset should be used instead
of embedding `%z` in a pattern.

`duration.seconds`/`minutes`/`hours`/`days(n: int) -> int` convert a
named unit into a plain epoch-second count (`duration.minutes(5)` is
`300`) — a readability convenience, not a distinct value kind. `int`
arithmetic on epoch seconds already covers every offset these
functions can express (`time.now() + duration.minutes(5)` is exactly
`time.now() + 300`), but it buys no type safety: a plain `int` offset
and an unrelated `int` (a user ID, a count) type-check identically,
so nothing stops a unit-confusion bug from compiling.

`Duration` is a distinct record type for when that safety matters — a
built-in record (`Duration { seconds: int }`, seeded the same way
`Option<T>`/`Result<T, E>` are) rather than a plain `int`.
`Duration.of_seconds`/`of_minutes`/`of_hours`/`of_days(n: int) ->
Duration` construct one; `Duration.add(a, b)`/`Duration.sub(a, b) ->
Duration` and `Duration.scale(d, factor: int) -> Duration` combine
them — plain named functions, not operators, since this language has
no operator overloading (§19). `Duration.to_seconds(d) -> int` bridges
back into plain-`int` epoch arithmetic:
`time.now() + Duration.to_seconds(Duration.of_minutes(5))`. Its
`seconds` field is also readable directly (`d.seconds`), since
`Duration` is an ordinary record. Passing a plain `int` where a
`Duration` is expected, or a `Duration` where a plain `int` is
expected, is a compile error — the concrete gap the lowercase
`duration.*` functions above cannot catch.

`bytes` is a distinct type from `str`, but under the hood a Lume `bytes`
value is represented exactly like `str` — a genuinely NUL-safe binary
type would require a change to Lume's runtime value representation,
which is out of scope today. Practically, this means content with an
embedded NUL byte silently truncates at the NUL when read back
(`bytes.to_str`, `fs.read_bytes`) — the same limitation Certo's own
underlying `Bytes.toText` conversion already has. This covers the large
majority of real payloads (JSON APIs, text-based formats, most file
content); `bytes.from_str(text) -> bytes` and `bytes.to_str(data) -> str`
convert between the two, `bytes.length(data) -> int` returns the byte
count, `fs.read_bytes(path) -> Result<bytes, str>` and
`fs.write_bytes(path, data) -> bool` mirror `fs.try_read_text`/
`fs.write_text` for binary-flavored file content, and
`http.request_bytes(method, url, headers, data) -> Result<http, str>` /
`http.body_bytes(response) -> bytes` mirror `http.request`/`http.body`
with a `bytes` body instead of `str`.

`process.run_with_input(exe, args, input) -> process` runs a command like
`process.run`, but writes `input` to its stdin before capturing
`stdout`/`stderr` — use the same `process.code`/`.stdout`/`.stderr`/`.ok`
accessors on the result. `process.run_with_env(exe, args, envMap) ->
process`, where `envMap: Map<str, str>`, runs a command with the given
variables overridden for the duration of that one call; each overridden
variable is restored to its prior value (or unset, if it wasn't set
before) once the call returns. `process.run_with_options(exe, args,
workingDir, timeoutMs) -> process` covers both a working directory and a
subprocess-level timeout: `workingDir` of `""` means "don't change
directory"; `timeoutMs <= 0` means no timeout. A timed-out process is
killed and reports `process.code(result) == -1` — the same value a
failed-to-spawn process reports, since the underlying result has no
separate "timed out" flag; don't rely on `-1` alone to distinguish the
two cases (a *test's* own timeout, §13, is a separate, independent
mechanism enforced by the interpreter, not by `process.run` itself).

`http.get(url) -> Result<http, str>` and `http.delete(url) ->
Result<http, str>` make a GET/DELETE request; `http.post(url, body,
content_type) -> Result<http, str>` and `http.put(url, body,
content_type) -> Result<http, str>` send `body` with the given
`Content-Type` header. `http.request(method, url, headers, body) ->
Result<http, str>`, where `headers: Map<str, str>`, sends any method
with arbitrary headers — the only builtin that can send an
`Authorization` header or anything else beyond a fixed
`Content-Type`. `http.request_bytes(method, url, headers, data) ->
Result<http, str>` mirrors `http.request` but takes a `bytes` body
instead of `str` (see §11's `bytes` section for the text-safe-subset
caveat this implies). All six share the same `http` result type and
accessors: `http.status(response) -> int`, `http.body(response) ->
str`, `http.content_type(response) -> str`, `http.ok(response) ->
bool` (true when `status` is in `[200, 300)`), or `http.body_bytes(response)
-> bytes`. `Err` covers both a
failed request (DNS/connect failure) and a response whose body exceeds
a fixed 10 MiB cap — the cap is checked only after the full response has
already been downloaded, since the underlying client has no streaming
or early-abort mode; it bounds what these builtins hand back, not the
network transfer itself. All six are Windows-only: the underlying
client is a stub on other platforms that aborts the process rather than
returning an error.

`fixture.temp_dir() -> str` creates and returns a fresh, unique
directory (under `%TEMP%`, falling back to `%TMP%` then `.`) — call
`fixture.cleanup(path) -> bool` to remove it recursively when done.
There is no automatic cleanup: like every other resource in Lume
(files, processes), a fixture must be cleaned up explicitly.
`env.set(name, value) -> bool` and `env.unset(name) -> bool` mutate the
whole process's environment directly (the same underlying mechanism
`process.run_with_env` already uses internally to scope its overrides).

## 12. Generic list transformations

Pass a statically-checked, non-capturing function reference with `&name`,
or an inline closure (§6), to `list.map`, `list.filter`, `list.find`, or
`list.fold`:

```lume
fn double(value: int) -> int { return value * 2 }
fn even(value: int) -> bool { return value % 2 == 0 }
fn add(total: int, value: int) -> int { return total + value }

let doubled = list.map([1, 2, 3], &double)
let evens = list.filter([1, 2, 3], &even)
let first_even = list.find([1, 2, 3], &even)
let total = list.fold([1, 2, 3], 0, &add)
let shifted = list.map([1, 2, 3], fn(value: int) -> int => double(value) + 1)
```

Callback parameter and return types are validated at compile time. There is
no bracket generic-call syntax — `json.decode[[User]](text)` from an
earlier draft was never implemented — the built-in containers infer their
type parameters from ordinary arguments instead.

**Callback bodies run in a separate interpreter, both for `&name` and for
inline closures** — a full bytecode-dispatch loop, not a deliberately
restricted sandbox, so it supports the same core language a normal
function body does: field access, arithmetic, comparisons, `if`/`while`,
if-as-an-expression, `match`, `?`/`!` result propagation, calls to other
user functions (including recursively, transitively), calls to builtins,
and `with` record updates all work inside a callback and anywhere in its
reachable call graph, including inside a native `test` block (which runs
through this same evaluator).

Protocols extend the constraint vocabulary and declare required method
signatures. `impl Named for User { ... }` must provide every declared method
with the exact signature and may not add undeclared methods. Implementations
compile to concrete `Type.method` functions; calls are statically resolved and
there are no trait objects or dynamic dispatch.

## 13. Testing

A `test "description" { ... }` block may appear anywhere a function
declaration can, in any file, and does not require an enclosing `fn main`
to run it — though the file must still declare one to compile:

```lume
test "adds two values" {
  expect.equal(add(20, 22), 42)
  expect.true(str.upper("lume") == "LUME")
}

fn main(args: [str]) -> int {
  return 0
}
```

An optional `, timeout: <milliseconds>` clause after the name bounds how
long the test body may run before it is failed automatically — protection
against an infinite loop in test code hanging the whole run. This is a
separate, independent mechanism from a subprocess's own timeout
(`process.run_with_options`, §11) - a test's `timeout:` bounds the
*interpreter* running the test body, not any process it happens to
spawn:

```lume
test "settles quickly", timeout: 500 {
  expect.true(settle())
}
```

A test with no `timeout:` clause is unbounded, exactly as before this
existed. On expiry the test fails with `test timed out after <n>ms`,
reported the same way any other assertion failure is, in both plain-text
and `--json` output.

`expect.equal`, `expect.true`, `expect.ok`, `expect.err`, and `expect.some`
are the assertions available inside a `test` block. Two more exist
specifically for asserting on a `process.run` result (§11):
`expect.exit_code(process, code: int) -> bool` and
`expect.stdout_contains(process, text: str) -> bool` /
`expect.stderr_contains(process, text: str) -> bool`, which check the
process's exit code or that its captured stdout/stderr contains a given
substring:

```lume
test "process exits cleanly" {
  let result = process.run("hostname.exe", [])
  expect.exit_code(result, 0)
  expect.stdout_contains(result, "")
}
```

Run one file, or a directory - every `*_test.lume` file found by a
recursive walk (a fixed 32-level depth bound, not a `--max-depth` flag,
generous enough for any real project layout while still bounding a
pathological or looping tree). `--ignore name1,name2` skips matching
directory names entirely, anywhere in the tree (checked by name, not
full path) - useful for excluding something like `node_modules`:

```powershell
.\dist\lume.exe test .\examples\native_tests.lume
.\dist\lume.exe test .\examples\native_suite
.\dist\lume.exe test .\examples\native_suite --ignore node_modules
```

`--filter text` runs only tests whose stable id (`<path>#<name>`, the
same id reported below) contains `text` — this matches everything a
bare name match would (the id always contains the name), plus a path
fragment now disambiguates same-named tests in different files; `--json`
switches every line of output to a JSON object instead of plain text,
for CI and editor integrations — both flags work in either order. Per
discovered test file (directory mode only): `{"event":"file","path":
"..."}`. Per test: `{"event":"test","id":"...","name":"...","status":
"pass"|"fail","line":N,"message":"..."}` (`message` is `""` for a
pass; `id` is `<path>#<name>` exactly as the path was passed on the
command line — capture it from one run to `--filter` an exact rerun).
Final summary: `{"event":"summary","passed":N,"failed":N,"total":N}`
(adds `"note"` only when zero tests were discovered). Plain-text output
is unchanged when `--json` is not passed.

## 14. Concurrency

Concurrency is intentionally deferred from the core. A later version may
add structured tasks with explicit `spawn` and `await`. Threads, async
coloring, actors, and callbacks should not all coexist; the design must
select one canonical model after measurement.

## 15. Grammar sketch

```text
file       := use_decl* declaration* EOF
declaration:= ('pub')? (function | record | enum | protocol | impl | test)
protocol   := 'protocol' ident '{' function_signature* '}'
impl       := 'impl' ident 'for' type '{' function* '}'
function   := 'fn' ident generic_params? '(' params? ')' '->' type block
generic_params := '<' generic_param (',' generic_param)* '>'
generic_param  := ident (':' ('Eq' | 'Ord' | 'Number' | 'Text' | ident))?
test       := 'test' string (',' 'timeout' ':' number)? '{' expect_call* '}'
block      := '{' newline statement* '}'
statement  := let_stmt | var_stmt | assignment | if_stmt | while_stmt
            | return_stmt | expression
expression := Pratt expression with fixed, non-overloadable operators;
              'match' is reachable as an atom, so it may nest, but a match
              *arm's* body is itself a single such expression, never a
              statement block — an arm cannot contain `return` or `if`
```

The complete grammar remains LL(2) outside expressions. There is no
`for_stmt`, `break_stmt`, or `continue_stmt` production (§7) - listed in
§19 as a gap rather than folded into this grammar, so the grammar here
matches what actually parses. Postfix `.field` chains onto any primary
expression, including a call's own result (§8), not just a bare name.

## 16. Compiler pipeline

```text
source bytes
  -> declaration/import scan
  -> parse + local typecheck + register-bytecode emission
  -> verifier
  -> content-addressed cache
  -> VM
```

The declaration scan records names, signatures, and byte offsets without
building function bodies. The second pass compiles each function
independently, enabling forward references and precise incremental caching.

## 17. Bytecode

The VM is a flat stack machine, not a register machine: every instruction
is one generic `{op, text, number, line}` record, and execution pushes and
pops an explicit value stack rather than addressing registers. `op`
selects behavior; `text` and `number` are untyped operand slots reused
differently per opcode (a constant's literal value, an operand count, a
jump offset); `line` is attached to every instruction directly, not kept
in a separate source map. A simple expression like `3 + 4` compiles to:

```text
const_int(3)
const_int(4)
add
return
```

(each line is one `{op, text, number, line}` record — `const_int` carries
its literal in `number`, `add`/`return` need no operand and just act on
whatever is already on the stack)

There is no per-function register count or constants table — constants
are inlined directly into the instructions that produce them. Richer
per-function metadata (return type, generics, constraints, and — for a
`test` declaration — its name and optional `timeout:` bound, §13) is
packed into one pipe-delimited string carried in a single `"function"`
instruction's `text` field, decoded by small accessor functions, rather
than stored as structured fields.

`run` maintains a content-hash-validated `.lbc` file: the source is
hashed and compared against the cached artifact's own stored hash, and an
unchanged source skips lexing, parsing, and re-emission entirely. Loading
that file back is a length-prefixed binary format (a fixed magic header,
the source hash, then each instruction's fields in sequence) validated
structurally at decode time — truncated or malformed framing is rejected
before a single instruction runs. There is no separate verification pass
beyond that framing check plus the interpreter's own refusal to execute
an opcode it doesn't recognize (protecting against a structurally-valid
but semantically-stale artifact, such as one built by an incompatible
compiler version).

## 18. Diagnostics contract

Every diagnostic has a stable code, primary span, short message, and
optional fix:

```text
E0611 examples/config.lume:3 cannot assign list<int> to list<any>
  fix: give the empty list literal a concrete type by returning it from a
  function whose declared return type names the element type (see §5)
```

The CLI supports both human text (default) and newline-delimited JSON
(`--json`). An AI tool consuming diagnostics should use `--json` and apply
fixes by span rather than by parsing the human-readable message, and should
not assume a suggested fix names a real function unless it has been
verified against `lume api`'s builtin list (§11) — a stale fix suggestion
naming a nonexistent conversion function is exactly the kind of error this
reconciliation pass found and removed from this document.

## 19. Current gaps versus durable design choices

These two lists look similar from the outside — both describe things a
program cannot do — but they answer different questions, and conflating
them (as the single "Deliberate exclusions" list in the previous draft did)
is misleading. A **durable exclusion** is a considered trade-off unlikely to
change without a specific, measured reason (§1's rules, or the
compile-time/AI-token benchmarks in `BENCHMARKS.md`). A **bootstrap gap** is
simply not built yet and carries no such argument against it.

**Durable, by design:**

- macros and metaprogramming
- operator overloading
- exceptions (failure is always a value, §9)
- implicit truthiness or coercion
- inheritance or structural subtyping
- dynamic/reflective typing
- compile-time execution or build scripts run during compilation
- multiple formatting styles (one formatter, §2)
- monomorphized/per-call-site generic codegen (generics exist, §6, but
  compile to type-erased runtime containers, not specialized code)

**Bootstrap gaps — no design objection, just not implemented:**

- string interpolation, `??`, and `T?` optional sugar
- `for`/`in` loops, `break`, `continue`
- `&&`/`||` symbol operators (use the `and`/`or`/`not` keywords, §7)
- `use ... as` import aliasing
- a `(key, value)`-style two-parameter callback for `map.*` transforms
  (today's `map.map`/`map.filter`/`map.fold` take the value only)
- closures/`&name` references as general first-class values (§6) — usable
  today only as the direct argument to the four `list.*` higher-order
  builtins
- `let`/`var` type annotations (§5)

Features may move from either list only if benchmarks show that their
value exceeds their cost in compile time, language-model error rate, and
specification size (`BENCHMARKS.md`).
