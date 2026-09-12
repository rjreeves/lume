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
- Newlines terminate statements except inside `[]` or `{}`. **Parenthesized
  argument lists — function calls, record construction, closure
  parameters — must stay on one line; a newline before the closing `)` is a
  parse error.** This is narrower than the general rule below would suggest,
  and is a bootstrap limitation rather than a design choice.
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
bool int float str
[T]             list
Map<K, V>       key/value map; K restricted to int, str, or bool
Option<T>       some T or none, spelled `Some`/`None`
Result<T, E>    ok T or err E, spelled `Ok`/`Err`
T ! E           sugar for a function's return type only; see §9
fn(A, B) -> C   the parameter type of a callback slot (see §12)
```

Integers are signed 64-bit. Floats are IEEE-754 binary64.

**Not yet implemented:** `bytes`, `unit`/`never` as usable types, and the
`T?` postfix sugar for `Option<T>` — write
`Option<T>` explicitly. There are no implicit conversions, and — contrary to
what the previous draft of this section claimed — there is currently **no
conversion function either**: no `int.parse`, no `int`-to-`str`, no
`str.from`. A program that needs to turn a number into displayable text has
no way to do it except `print`/`eprint`, which accept any scalar directly.

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
(§12). **There is also no `&&`, `||`, or `not`/`!` boolean operator** —
compose conditions with nested `if` statements, and write predicate
functions that return the polarity you need directly rather than negating
one.

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

**Record- and enum-construction calls, like all call argument lists, must
fit on one line** (§2) — a multi-line `User(\n  name: "Ada",\n  ...\n)` is a
parse error, contrary to what §2's general newline rule would otherwise
suggest. **Field access directly on a call expression's result is also not
supported** — `list.get(users, 0).name` is a parse error; bind the call's
result to a `let` first:

```lume
let user = list.get(users, 0)
print(user.name)
```

JSON decodes directly into a record via `Type.from_json(text)`, returning
the shorthand `str`-error result described in §9. Decoding supports `str`,
`int`, `bool`, nested records, and lists of records recursively (including
lists of records nested inside other records). **It does not support enum
fields** — a JSON payload with fields that map onto enum variants should
decode into a flat record of scalars first, then be classified into an enum
by ordinary code:

```lume
fn classify(raw: RawTask) -> Status {
  if raw.status_code == "done" {
    return Status.done(completed_by: raw.completed_by)
  }
  return Status.pending()
}
```

There is currently **no JSON encoder** — decoding is one-directional. A
program that needs to persist structured data back out has to hand-build
the text itself with string concatenation, or write plain text with
`fs.write_text`/`fs.try_write_text`.

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

### Two different `Result` representations

This is the sharpest gap between the previous draft and reality: **there
are two, non-interchangeable ways to work with a fallible value**, depending
on how the function declares its return type.

**Shorthand, `str`-only errors** — a function declared with `T ! E` where
`E` is `str`:

```lume
fn upper_file(path: str) -> str ! str {
  let content = fs.try_read_text(path)?
  return result.ok(str.upper(content))
}
```

is inspected with the builtin functions `result.is_ok`, `result.value`, and
`result.error` — never `match`:

```lume
let outcome = upper_file(path)
if result.is_ok(outcome) {
  print(result.value(outcome))
} else {
  eprint(result.error(outcome))
}
```

`result.ok`/`result.err` construct this shape, and `result.err` rejects any
error value that isn't `str`. Every I/O builtin that can fail
(`fs.try_read_text`, `fs.try_write_text`, `Type.from_json`) returns this
shape.

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
— the `result.*` builtins reject it outright (`result operation requires
result value`) because they only recognize the shorthand shape above.

`?` (and the compatibility spelling `!`) propagates an error out of the
current function immediately in both shapes, as long as the enclosing
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

## 11. Standard library

APIs follow `noun.verb` naming. The current, complete builtin surface
(regenerate with `lume api` after any compiler change) is:

```text
args.count()                  args.get(index)
fs.exists(path)                fs.read_text(path)
fs.write_text(path, text)      fs.try_read_text(path)
fs.try_write_text(path, text)
env.get(name)                  env.has(name)
process.run(exe, args)         process.ok(result)
process.code(result)           process.stdout(result)
process.stderr(result)
str.len(text)                  str.trim(text)
str.upper(text)                str.lower(text)
str.contains(text, part)       str.starts_with(text, prefix)
str.ends_with(text, suffix)
json.valid(text)                json.get(text, key)
list.len(values)                list.get(values, index)
list.push(values, item)         list.map/filter/find/fold(...)
map.new()                        map.len(m)
map.get(m, key)                  map.has(m, key)
map.set(m, key, value)           map.remove(m, key)
map.keys(m)                      map.values(m)
map.map/filter/fold(...)
result.ok(value)                result.err(message)
result.is_ok(result)            result.value(result)
result.error(result)
expect.equal/true/ok/err/some(...)   (inside `test { ... }` blocks only, §13)
```

**`http.*` and `time.*` do not exist yet**, despite appearing as
illustrative naming-convention examples in earlier drafts of this document.
`map.map`/`map.filter`/`map.fold` mirror the `list.*` transforms exactly,
except the callback takes the value only (`(V) -> ...`) — keys pass
through unchanged for `map.map`/`map.filter`. There is no `(key, value)`
two-parameter callback shape yet.

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

**Callback bodies run in a restricted evaluator, both for `&name` and for
inline closures.** Field access, arithmetic, comparisons, `if`/`while`,
calls to other user functions (including recursively, transitively), calls
to builtins, and `with` record updates all work inside a callback. The one
thing that still does not work, anywhere in a callback's reachable call
graph, is `match` — a callback (or any function it calls) that contains
`match` fails at *run time*, not compile time, with `callback uses
unsupported operation`. Something that needs to pattern-match on an enum
inside a transformation should be written as an ordinary `while`-loop
function called directly, not passed as `&name` or a closure.

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

`expect.equal`, `expect.true`, `expect.ok`, `expect.err`, and `expect.some`
are the assertions available inside a `test` block. Run one file, or an
entire directory (every `.lume` file found, recursively):

```powershell
.\dist\lume.exe test .\examples\native_tests.lume
.\dist\lume.exe test .\examples\native_suite
```

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
test       := 'test' string '{' expect_call* '}'
block      := '{' newline statement* '}'
statement  := let_stmt | var_stmt | assignment | if_stmt | while_stmt
            | return_stmt | expression
expression := Pratt expression with fixed, non-overloadable operators;
              'match' is reachable as an atom, so it may nest, but a match
              *arm's* body is itself a single such expression, never a
              statement block — an arm cannot contain `return` or `if`
```

The complete grammar remains LL(2) outside expressions. There is no
`for_stmt`, `break_stmt`, or `continue_stmt` production (§7), and no general
postfix `.field` production after a call expression (§8) — both are listed
in §19 as gaps rather than folded into this grammar, so the grammar here
matches what actually parses.

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

A register VM reduces instruction count and dispatch compared with a stack
VM:

```text
load_const r0, #3
load_const r1, #4
add_int    r2, r0, r1
return     r2
```

Each function stores its register count, constants, instructions, result
metadata, and a compressed source map. Bytecode is verified once before
caching, and `run` maintains a content-hash-validated `.lbc` file so an
unchanged source skips lexing, parsing, and re-emission entirely.

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
- `&&`, `||`, `not` boolean operators
- `int`↔`str` conversion of any kind
- a JSON encoder (decode-only today, §8)
- `use ... as` import aliasing
- a `(key, value)`-style two-parameter callback for `map.*` transforms
  (today's `map.map`/`map.filter`/`map.fold` take the value only)
- closures/`&name` references as general first-class values (§6) — usable
  today only as the direct argument to the four `list.*` higher-order
  builtins
- `match` inside a `list.*` callback's reachable call graph (§12)
- multi-line call/record-construction argument lists (§2, §8)
- postfix field access directly on a call expression's result (§8)
- `let`/`var` type annotations (§5)

Features may move from either list only if benchmarks show that their
value exceeds their cost in compile time, language-model error rate, and
specification size (`BENCHMARKS.md`).
