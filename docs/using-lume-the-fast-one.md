# Using Lume — The Fast One

## A practical guide to small, safe, fast automation

Lume is a focused scripting language for work that has outgrown a shell script
but does not need a large application stack. It combines short programs,
static checking, structured data, explicit errors, fast compilation, and a
small API surface that is easy for people and AI systems to learn.

This book describes the language that exists today. Its examples are designed
to be copied, checked, and adapted.

---

## Contents

1. Why Lume
2. Your first program
3. Values, bindings, and expressions
4. Control flow
5. Functions and recursion
6. Lists and transformations
7. Records and immutable updates
8. Enums and exhaustive matching
9. Generics
10. Option and Result
11. JSON and files
12. Processes and environment values
13. Modules
14. Building, bytecode, and performance
15. Editor and AI tooling
16. A complete automation program
17. Design habits
18. Current boundaries

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
- structured around records, enums, lists, and results;
- compiled to compact, validated bytecode;
- intentionally small enough to describe to an AI model;
- designed around a 10,000-source-lines-per-second compilation target.

The current 10,000-line benchmark runs at roughly 31,000 lines per second on
the development machine. Treat that as a local measurement, not a universal
hardware-independent promise.

## 2. Your first program

Create `hello.lume`:

```lume
fn main(args: [str]) -> int {
  let name = list.get(args, 0) ?? "world"
  print("Hello, " + name)
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

Useful front-door commands are:

```text
lume run program.lume
lume check program.lume
lume tokens program.lume
lume bytecode program.lume
lume build program.lume program.lbc
lume exec program.lbc
lume benchmark program.lume 100
lume fmt program.lume
lume api
lume ai-reference
```

Use `check` in fast feedback loops: it validates a program without running its
effects.

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

The compiler rejects assignment to `let`, inconsistent reassignment, unknown
names, invalid operands, and calls with the wrong arity.

Arithmetic and comparison operators are deliberately familiar:

```lume
let cost = count * price
let ready = retries < 3
let same = left == right
```

String concatenation uses `+`:

```lume
let message = "service=" + service
```

## 4. Control flow

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

The checker prevents integers, strings, or records from being used as accidental
conditions.

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

The basic immutable list operations are:

```lume
list.len(values)
list.get(values, 0)
list.push(values, new_value)
```

`list.push` returns a new list. It does not change the original.

Lume also provides typed transformations. A function reference uses `&name`:

```lume
fn double(value: int) -> int {
  return value * 2
}

fn even(value: int) -> bool {
  return value % 2 == 0
}

fn add(total: int, value: int) -> int {
  return total + value
}

let values = [1, 2, 3, 4]
let doubled = list.map(values, &double)
let evens = list.filter(values, &even)
let first_even = list.find(values, &even)
let total = list.fold(values, 0, &add)
```

Callback input and output types are checked at compile time. Inline closures use
`fn(parameter: type) -> return_type => expression` and may capture immutable
bindings:

```lume
let offset = 10
let shifted = list.map(values, fn(value: int) -> int => value + offset)
```

Mutable captures are rejected. A closure can call ordinary functions and use
the same expression operations as other Lume code.

## 7. Records and immutable updates

Records give names and types to related data:

```lume
type Database {
  host: str
  port: int
  secure: bool
}

let database = Database(
  host: "db.internal",
  port: 5432,
  secure: true
)

print(database.host)
```

Construction requires every field exactly once. Unknown fields, missing fields,
duplicates, and incorrect values are rejected.

Use `with` to create a changed copy:

```lume
let local = database with {
  host: "localhost"
  secure: false
}
```

The original remains unchanged. Updates may be nested:

```lume
type Preferences {
  theme: str
}

type User {
  name: str
  preferences: Preferences
}

let darker = user with {
  preferences: user.preferences with {
    theme: "dark"
  }
}
```

Immutable updates reduce hidden state changes and make generated code easier to
review.

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

`match` is an expression. Every variant must be handled exactly once:

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

Payload names exist only inside their arm and receive their types from the enum
declaration. The compiler rejects missing arms, duplicate arms, unknown variants,
incorrect destructuring, and incompatible arm results.

## 9. Generics

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
type Box<T> {
  value: T
}

enum Maybe<T> {
  Some(value: T)
  None
}

let boxed = Box(value: 42)
let present = Maybe.Some(value: "ready")
```

The compiler infers substitutions from call and constructor arguments. Nested
forms such as `Result<[User], str>` are parsed as structured types rather than
unstructured text.

Generic callbacks work with list transformations:

```lume
fn keep<T>(value: T) -> T {
  return value
}

let unchanged = list.map([1, 2, 3], &keep)
```

Constrain a generic function when its callers must supply a particular family
of values:

```lume
fn keep_number<T: Number>(value: T) -> T {
  return value
}
```

The built-in constraints are `Eq` for equality-capable scalar values, `Ord` for
ordered integers and strings, `Number` for integers, and `Text` for strings.
They are checked after type inference and erased before execution.

## 10. Option and Result

`Option<T>` represents a value that may be absent. `Result<T, E>` represents
success or a typed failure. Both are available without a declaration.

`list.find` returns an option:

```lume
let selected = list.find(values, &even)
let display = match selected {
  Some(value) => value
  None => 0
}
```

Construct and match results explicitly:

```lume
fn validate(port: int) -> Result<int, str> {
  if port > 0 {
    return Result.Ok(value: port)
  }
  return Result.Err(error: "port must be positive")
}
```

The `?` postfix operator extracts success and immediately returns failure:

```lume
fn checked_port() -> Result<int, str> {
  let port = validate(5432)?
  return Result.Ok(value: port)
}
```

The compiler verifies that `?` appears inside a result-returning function and
that the propagated error type matches. The older `!` spelling remains available
for compatibility with existing Lume programs.

## 11. JSON and files

Decode JSON directly into a record schema:

```lume
type User {
  name: str
  active: bool
}

fn decode(input: str) -> result<User, str> {
  let user = User.from_json(input)!
  return result.ok(user)
}
```

Decoding checks schemas recursively, including nested records and lists.
Errors contain the failing field path. Missing, unknown, and incorrectly typed
fields are not silently accepted.

Core file operations include:

```lume
fs.exists(path)
fs.read_text(path)
fs.write_text(path, content)
fs.try_read_text(path)
fs.try_write_text(path, content)
```

Prefer the `try_` forms when failure is expected and should remain data. The
non-try forms are useful when failure should stop the program.

## 12. Processes and environment values

Run a process with an explicit executable and list of arguments:

```lume
let process = process.run("git", ["status", "--short"])

if process.ok(process) {
  print(process.stdout(process))
} else {
  eprint(process.stderr(process))
}
```

Process output is structured. Access its exit code, standard output, standard
error, and success flag with `process.code`, `process.stdout`, `process.stderr`,
and `process.ok`.

Read environment values with:

```lume
let configured = env.has("DATABASE_URL")
let database_url = env.get("DATABASE_URL")
```

Arguments remain lists rather than interpolated command strings. This keeps
spaces and quoting predictable and avoids an entire class of shell mistakes.

## 13. Modules

Split related functions into files and import them with `use`.

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

Module paths are resolved from source files, and cycles are reported explicitly.
Use modules to separate reusable domain operations from command-line entry points.

## 14. Building, bytecode, and performance

### Native tests

A native test has a descriptive string name and a block of expectations:

```lume
test "calculates the total" {
  expect.equal(list.fold([1, 2, 3], 0, &add), 6)
}
```

Run all tests in a source file with `lume test tests.lume`. The runner reports
individual results, prints the passed/failed totals, and exits unsuccessfully
if any expectation or runtime operation fails. Assertions include
`expect.equal`, `expect.true`, `expect.some`, `expect.ok`, and `expect.err`.
Failure output contains the test declaration line and expected/actual values
where applicable. Select tests by name with `--filter text`.
Passing a directory discovers each direct `*_test.lume` child.

### Protocol methods

User-defined constraints can require statically dispatched methods:

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

The compiler verifies the protocol and target type, implementation uniqueness,
and every method name, parameter, and return type. Methods lower to concrete
functions and are called with qualified syntax such as `User.name(user)`.
There is no runtime method lookup.

`lume run` maintains a hash-validated `.lbc` bytecode cache beside the source.
Unchanged source can skip lexing, parsing, static validation, and emission.

Build and execute an artifact explicitly when packaging a script:

```text
lume build deploy.lume deploy.lbc
lume exec deploy.lbc
```

The binary artifact records source identity, strings, integer operands, and
instructions with validated boundaries. Truncated or corrupt bytecode is
rejected rather than partially executed.

Measure compiler throughput in-process:

```text
lume benchmark deploy.lume 1000
```

The repository also contains a fixed 10,000-line benchmark. The feature series
used while preparing this book measured:

| Compiler stage | Lines/second |
| --- | ---: |
| Generic function substitution | 32,165 |
| Generic records, enums, Option, and Result | 33,167 |
| List transformations | 31,536 |
| Result propagation | 30,769 |
| Final validation run, 30 iterations | 32,268 |
| Closures and function values, 30 iterations | 31,371 |
| Generic constraints and native test runner, 30 iterations | 31,221 |
| Named test blocks and expectations, 30 iterations | 31,682 |
| Test discovery and marker protocols, 30 iterations | 30,142 |
| Protocol methods with static dispatch, 30 iterations | 30,915 |

Short runs vary with operating-system scheduling and machine load. Compare
median results on the same machine and workload. Lume's design gate rejects a
core feature that causes more than a five-percent median clean-compile
regression unless its usefulness clearly offsets the cost.

Fast compilation matters beyond developer comfort. It shortens AI repair loops,
makes checking on every edit inexpensive, and keeps small scripts feeling small.

## 15. Editor and AI tooling

The Lume language server provides editor-facing diagnostics and language
support. The `lsp` directory contains its launcher and tests.

For AI generation, two commands expose the language in compact forms:

```text
lume api
lume ai-reference
```

`api` returns a machine-readable feature and builtin manifest.
`ai-reference` returns a concise generation guide. Together they reduce the
amount of prompt material needed before a model can produce valid Lume.

Good AI prompts state:

- input and output data shapes;
- permitted effects, such as files or subprocesses;
- desired exit-code behavior;
- whether failures should be returned or terminate execution;
- concrete examples of expected output.

Then ask the model to check the program before running it. Static diagnostics
make repair local and specific.

## 16. A complete automation program

The following program reads typed JSON configuration, runs a command, and
returns a meaningful exit code. It illustrates the preferred Lume shape:
records at the boundary, small functions in the middle, and effects near
`main`.

```lume
type CommandConfig {
  executable: str
  arguments: [str]
}

type AppConfig {
  name: str
  command: CommandConfig
}

fn load_config(path: str) -> result<AppConfig, str> {
  let source = fs.try_read_text(path)!
  let config = AppConfig.from_json(source)!
  return result.ok(config)
}

fn main(args: [str]) -> int {
  let path = list.get(args, 0) ?? "app.json"
  let loaded = load_config(path)

  if result.is_ok(loaded) {
    let config = result.value(loaded)
    let completed = process.run(
      config.command.executable,
      config.command.arguments
    )

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

Example `app.json`:

```json
{
  "name": "repository status",
  "command": {
    "executable": "git",
    "arguments": ["status", "--short"]
  }
}
```

There is no command-string interpolation, configuration fields are checked,
JSON failures preserve their paths, and every operational outcome becomes an
explicit exit code.

## 17. Design habits

Prefer these habits in production Lume:

1. Model external data with records immediately after reading it.
2. Model state transitions with enums rather than strings.
3. Keep bindings immutable unless a loop genuinely needs mutation.
4. Use `Result` for expected failure and `?` for short propagation paths.
5. Handle `Option` and enum values with exhaustive `match`.
6. Pass process arguments as lists, never as constructed shell command text.
7. Keep list callbacks small; use named functions or immutable-capture closures.
8. Put reusable logic in modules and effects near `main`.
9. Run `lume check` continuously and test both success and failure paths.
10. Measure compiler performance after expanding the language core.

These conventions also improve AI output: fewer implicit rules mean fewer
plausible but incorrect programs.

## 18. Current boundaries

Lume is deliberately young and focused. It is not trying to replace every
general-purpose language. Current boundaries include:

- closures capture immutable values only; mutable captures are intentionally rejected;
- a compact standard library rather than a large package ecosystem;
- an evolving generic system without traits or type classes;
- closures are expression-bodied rather than statement-bodied;
- bootstrap tooling that is still maturing;
- performance figures measured on the development machine, not a broad suite
  of production hardware.

These constraints are useful when choosing Lume. Use it for typed automation,
data transformation, command orchestration, configuration handling, and compact
tools where rapid checking matters. Choose a broader language when a task needs
a mature third-party library ecosystem, complex concurrency, a GUI framework,
or unrestricted systems programming.

---

## Closing: fast is a workflow

Lume's speed is not only compiler throughput. It is the speed of discovering a
mistake before a deployment starts, understanding a script months later,
generating a valid first draft with AI, and changing a data shape without
guessing which paths will break.

That is the promise behind “the fast one”: a small language that turns the edit,
check, understand, and run loop into one short motion.
