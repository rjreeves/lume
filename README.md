# Lume

Lume is a small, statically checked scripting language designed for:

1. extremely fast source-to-bytecode compilation;
2. reliable, low-token AI code generation;
3. readable automation, CLI, data, and service scripts.

The name is provisional. The design is the important part. This repository now
includes a Certo-written bootstrap compiler and bytecode VM.

Read the practical guide: [Using Lume — The Fast One](docs/using-lume-the-fast-one.md).

```lume
use http

fn main(args: [str]) -> int {
  let name = list.get(args, 0) ?? "world"
  print("hello, {name}")
  return 0
}
```

## Design target

For a warm compiler process on commodity hardware:

- compile 10,000 lines in under 10 ms;
- compile time and memory scale linearly with source size;
- begin executing a small cached script in under 5 ms;
- produce one deterministic diagnostic per root error;
- keep common programs smaller than equivalent Python or TypeScript token counts;
- give an AI one canonical, formatter-enforced way to express each construct.

These are benchmark targets, not claims until an implementation is measured.

## Why it should compile quickly

Lume performs a declaration scan followed by a single parse/typecheck/bytecode-emission pass. It deliberately excludes features that commonly make compilers slow:

- no global type inference;
- no function or operator overloading;
- no templates, macros, or conditional compilation;
- no inheritance or implicit interface conformance;
- no user-defined implicit conversions;
- no monomorphization;
- no source-level package graph resolution during compilation.

Functions have explicit parameter and result types. Local variables are inferred from their initializer. Generic behavior is provided by a small set of built-in containers compiled once in the runtime.

## Why AI should generate it quickly

Lume minimizes choice and repair loops:

- one formatter and one canonical syntax;
- keywords are short but unsurprising;
- newline-terminated statements; no semicolons;
- braces make block boundaries explicit;
- string interpolation uses the same braces;
- no truthiness, implicit null, shadowing, or ambiguous coercions;
- errors include machine-readable codes and exact fix suggestions;
- the core language fits in a short prompt or model context;
- standard APIs use predictable `noun.verb` names.

Token count alone is not the objective. A cryptic language may use fewer tokens per attempt but require more retries. Lume optimizes **tokens to a compiling solution**.

## Example

```lume
use fs
use json

type Config {
  host: str
  port: int = 5432
}

fn load_config(path: str) -> Config ! str {
  let text = fs.read_text(path)!
  return json.decode[Config](text)!
}

fn main(args: [str]) -> int {
  let path = list.get(args, 0) ?? "config.json"

  match load_config(path) {
    ok config => print("{config.host}:{config.port}")
    err message => {
      eprint(message)
      return 1
    }
  }

  return 0
}
```

## Repository contents

- [SPEC.md](SPEC.md) — language and implementation design
- [examples/](examples) — representative programs
- [BENCHMARKS.md](BENCHMARKS.md) — how the goals must be tested
- [src/lume.cto](src/lume.cto) — lexer, parser, bytecode emitter, and VM in Certo
- [lsp/](lsp/) — editor language server (diagnostics, completion, hover, definitions, formatting)

## Build the bootstrap compiler

```powershell
.\build.ps1
```

This creates `dist\lume.exe`. The bootstrap currently implements the deliberately
small executable core: `fn main`, integer/string/boolean literals, `let`, `var`,
assignment, arithmetic, comparisons, `if`/`else`, `while`, `print`, `eprint`,
typed user functions, forward calls, recursion, and integer `return`.
Homogeneous list literals and inferred list types are supported through
`list.len`, `list.get`, and immutable `list.push`.

`check` also rejects undefined bindings, duplicate bindings, and assignment to
immutable `let` bindings before the VM runs.
Function declarations are also checked for duplicate names, unknown calls, and
incorrect argument counts.

The native check, build, manifest, static-validation, and runtime-check workflow
can also be run entirely through ion-win, without PowerShell:

```powershell
ion-win.exe certo-toolchain.ion
```

## Editor support

After building Lume, point any standard LSP client at:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\lsp\lume-lsp.ps1
```

The server validates unsaved buffers with the Certo-built compiler and supports
live diagnostics, completion, hover, go-to-definition, and formatting. See
[`lsp/README.md`](lsp/README.md) for details.

The emitted bytecode is verified in a linear static-type pass. It checks operand
types, assignment consistency, boolean conditions, homogeneous lists, function
argument types, builtin argument types, and declared return types before a
program can run or be cached.

The bootstrap includes canonical scripting APIs:

```text
args.count()                 args.get(index)
fs.exists(path)              fs.read_text(path)
fs.write_text(path, text)
fs.try_read_text(path)       fs.try_write_text(path, text)
env.get(name)                env.has(name)
process.run(executable, args) process.ok(result)
process.code(result)          process.stdout(result)
process.stderr(result)
str.len(text)                str.trim(text)
str.upper(text)              str.lower(text)
str.contains(text, part)     str.starts_with(text, prefix)
str.ends_with(text, suffix)
json.valid(text)             json.get(text, key)
list.len(values)             list.get(values, index)
list.push(values, item)
result.ok(value)              result.err(message)
result.is_ok(result)          result.value(result)
result.error(result)
```

Functions declare structured failures as `value_type ! error_type`. Postfix `!`
unwraps an `ok` value or immediately propagates an `err` result from the current
result-returning function. There are no exceptions or hidden stack unwinds.

## Modules

Modules use deterministic file-relative imports. Dotted module names map directly
to paths, so `use app.math` loads `app/math.lume` relative to the importing file.

```lume
use modules.stats

fn main(args: [str]) -> int {
  print(stats.sum_of_squares(3, 4))
  return 0
}
```

Exported functions use `pub fn` and qualified names:

```lume
pub fn stats.sum_of_squares(left: int, right: int) -> int {
  return left * left + right * right
}
```

Imports are loaded recursively and once per graph. Missing modules, import cycles,
and duplicate function symbols are compile errors. The bytecode cache hashes the
combined dependency graph, so changing any imported file invalidates the root cache.

```powershell
.\dist\lume.exe check .\examples\arithmetic.lume
.\dist\lume.exe bytecode .\examples\arithmetic.lume
.\dist\lume.exe run .\examples\arithmetic.lume
.\dist\lume.exe run .\examples\control_flow.lume
.\dist\lume.exe run .\examples\functions.lume
.\dist\lume.exe run .\examples\core_api.lume .\examples\data.json
.\dist\lume.exe run .\examples\lists.lume
.\dist\lume.exe run .\examples\process.lume
.\dist\lume.exe run .\examples\structured_errors.lume .\examples\data.json
```

Run the bootstrap smoke tests with:

```powershell
.\test.ps1
```

Lume programs can also contain named native tests:

```lume
test "adds two values" {
  expect.equal(add(20, 22), 42)
}
```

Run every test in a file with `lume test tests.lume`. Each test is reported as
PASS or FAIL, followed by a summary; any failure produces exit code 1. Use
`--filter text` to select tests by name. Assertions include `expect.equal`,
`expect.true`, `expect.some`, `expect.ok`, and `expect.err`.

Passing a directory discovers every direct child named `*_test.lume`:

```text
lume test tests
```

The broader syntax in the specification is the roadmap, not yet all implemented
by the bootstrap.

### Records

Records provide statically checked structured data with named construction and
field access:

```lume
type User {
  name: str
  age: int
}

fn describe(user: User) -> str {
  return user.name
}

fn main(args: [str]) -> int {
  let user = User(name: "Ada", age: 36)
  print(describe(user))
  return 0
}
```

Every declared field must be supplied exactly once. Unknown fields, missing
fields, invalid field access, and field values of the wrong type are compile
errors. Records may contain other records and homogeneous lists.

Records are updated immutably with `with`:

```lume
let updated = user with {
  active: true
  retries: user.retries + 1
}
```

Multiple fields and nested records can be updated in one expression. The
source record and each replacement expression are evaluated once, the original
record remains unchanged, and unknown, duplicate, or incorrectly typed fields
are rejected during compilation.

JSON can be decoded directly into a record. Decoding is schema-driven at
runtime and returns a checked result:

```lume
let decoded = User.from_json(text)
let user = result.value(decoded)
print(user.name)
```

Nested records and lists of records are decoded recursively. Missing fields,
unknown fields, and incorrect value types produce errors containing the exact
field path, such as `User.address.city must be str`.

### Enums

Enums define a closed set of named variants. Variants may be empty or carry
statically checked payload fields:

```lume
enum JobState {
  pending
  completed(code: int)
  failed(message: str)
}

let waiting = JobState.pending()
let done = JobState.completed(code: 0)
```

Enum values can be passed to and returned from functions using the enum name as
their type. The compiler rejects unknown variants and missing, unexpected,
duplicate, or incorrectly typed payload fields.

`match` is an expression and evaluates only its selected arm:

```lume
fn describe(state: JobState) -> str {
  return match state {
    pending => "waiting"
    completed(code) => "completed"
    failed(message) => message
  }
}
```

Every variant must appear exactly once, and every arm must produce a compatible
type. Non-enum subjects, impossible variants, duplicate arms, non-exhaustive
matches, and inconsistent arm result types are compile errors. Payload fields
are destructured positionally using names chosen by the arm. Their types come
from the variant declaration, they exist only within that arm, and a bare arm
such as `completed => ...` explicitly ignores its payload.

### Generics, options, and results

Functions, records, enums, and lists accept generic type parameters. Calls and
constructors infer concrete types from their arguments:

```lume
type Box<T> { value: T }

fn identity<T>(value: T) -> T {
  return value
}

let number = Box(value: identity(42))
```

Generic functions may constrain inferred types with one of four lightweight,
built-in requirements: `Eq`, `Ord`, `Number`, or `Text`.

```lume
fn keep_number<T: Number>(value: T) -> T {
  return value
}
```

Constraints are checked at the call site and remain type-erased at runtime, so
they do not introduce monomorphization cost.

Projects can declare marker protocols and opt records, enums, or scalar types
into them explicitly:

```lume
protocol Named {}
impl Named for User {}

fn keep_named<T: Named>(value: T) -> T {
  return value
}
```

Protocol and implementation bodies are intentionally empty in this first
stage. They provide user-defined generic constraints without dynamic dispatch.

`Option<T>` and `Result<T, E>` are always available. Their variants work with
the same exhaustive `match` syntax as declared enums. Use `?` inside a
result-returning function to return an error immediately; `!` remains supported
as a compatibility spelling.

```lume
fn load() -> Result<str, str> {
  let text = fs.try_read_text("config.json")?
  return Result.Ok(value: text)
}
```

### Generic list transformations

Pass a statically checked named function with `&name`, or use an inline closure:

```lume
fn double(value: int) -> int { return value * 2 }
fn even(value: int) -> bool { return value % 2 == 0 }
fn add(total: int, value: int) -> int { return total + value }

let doubled = list.map([1, 2, 3], &double)
let evens = list.filter([1, 2, 3], &even)
let first_even = list.find([1, 2, 3], &even)
let total = list.fold([1, 2, 3], 0, &add)
let offset = 10
let shifted = list.map([1, 2, 3], fn(value: int) -> int => double(value) + offset)
```

Callback parameter and return types are validated at compile time. A plain
`&name` function reference is deliberately non-capturing and runs in a
restricted evaluator: it may use parameters, literals, arithmetic,
comparisons, and other function references, but not field access, `match`,
or calls into other functions — not even builtins like `str.len`. An inline
closure (`fn(value: int) -> int => ...`) may capture immutable `let`
bindings instead; capturing mutable `var` bindings is rejected, so a closure
is a stable snapshot rather than shared mutable state. Transformations over
records or enums, or anything that needs a helper call, should be written as
ordinary `while`-loop functions or an inline closure rather than a `&name`
reference.

## Example: a multi-module task board

[`examples/task_board.lume`](examples/task_board.lume) and
[`examples/task_board/`](examples/task_board) are a larger, deliberately
"real" program built from everything above: a JSON-backed task tracker split
across five modules (`model`, `rules`, `board`, `render`, `insights`). It
decodes a flat JSON seed file into typed records, promotes it into a domain
model with payload-carrying enums (`Status`, `Priority`), validates it with a
structured error enum, and answers a handful of CLI commands by combining
`while`-loop traversal, `list.fold`/`list.filter`, `Option<T>` (including a
user-defined generic `first<T>`), `Result<T, E>`, immutable record updates,
and file I/O (`fs.try_write_text` for `export`).

```powershell
.\dist\lume.exe run .\examples\task_board.lume .\examples\task_board\seed.json board
.\dist\lume.exe run .\examples\task_board.lume .\examples\task_board\seed.json blocked
.\dist\lume.exe run .\examples\task_board.lume .\examples\task_board\seed.json stats
.\dist\lume.exe run .\examples\task_board.lume .\examples\task_board\seed.json next
.\dist\lume.exe run .\examples\task_board.lume .\examples\task_board\seed.json complete t-1 Ada
.\dist\lume.exe run .\examples\task_board.lume .\examples\task_board\seed.json search auth
.\dist\lume.exe run .\examples\task_board.lume .\examples\task_board\seed.json export board.txt
```

## Bytecode cache and performance

`run` maintains a content-hash-validated `.lbc` file beside its source. If the
source hash matches, Lume skips lexing, parsing, validation, and bytecode emission.
Changing the source automatically rebuilds the cache.

Bytecode can also be built and executed explicitly:

```powershell
.\dist\lume.exe build .\examples\functions.lume .\dist\functions.lbc
.\dist\lume.exe exec .\dist\functions.lbc
```

Measure the in-process compiler and artifact decoder:

```powershell
.\dist\lume.exe benchmark .\examples\functions.lume 1000
```

Measure complete process startup, checking, cached execution, and artifact
execution:

```powershell
.\benchmark.ps1 -Iterations 100
```

The `LBC4` artifact is a compact length-prefixed binary file. It records a
SHA-256 source hash, instruction count, source lines for diagnostics, and VM
instructions. The decoder validates every record boundary and rejects corrupt,
truncated, or unsupported files. `.lbc` files are ignored by Git because they
are reproducible build products.

## AI tooling

```powershell
.\dist\lume.exe check .\program.lume --json
.\dist\lume.exe fmt .\program.lume
.\dist\lume.exe fmt .\program.lume --check
.\dist\lume.exe api
.\dist\lume.exe ai-reference
.\ai-eval.ps1 -Candidates .\generated-candidates
```

The build generates `ai\lume-api.json`, a machine-readable list of supported
features and built-ins. `ai\SYSTEM_PROMPT.md` is a compact generation contract,
while `ai\tasks.json` and `ai-eval.ps1` provide a fixed correctness suite for
comparing models, prompts, and language revisions.

## Recommended implementation

Write the compiler and VM in Rust or Zig. Emit a compact register bytecode directly during parsing, cache it by content hash, and embed a small standard runtime. Do not start with LLVM: it improves peak native performance, not the compile-time goal of this language.
