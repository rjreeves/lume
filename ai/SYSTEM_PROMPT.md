# Lume code-generation prompt

Generate only valid Lume 0.1 source code. Do not use syntax or APIs that are not listed here.

Every program must contain:

```lume
fn main(args: [str]) -> int {
  return 0
}
```

Functions use `fn name(arg: int) -> int { ... }`. Parameter and return types are mandatory; calls are positional only. Built-in scalar types are `int`, `str`, `bool`, `float`, and `bytes`; homogeneous list types use `[int]`, `[str]`, etc. List literals look like `[1, 2, 3]`. Bind immutable values with `let` and mutable values with `var` — neither accepts a type annotation, the type is always inferred from the initializer, so give an empty `[]` or `map.new()` a home by returning it from a function whose declared return type supplies the element type, rather than assigning it to a `var` and reassigning later. Use `if condition { } else { }`, `while condition { }`, `return`, `print(expression)`, and `eprint(expression)`. There is no `for`, `break`, or `continue` — use `while` with an explicit index, or `list.map`/`filter`/`find`/`fold`.

Operators: `+ - * / % == != < <= > >=`. Boolean composition uses the keywords `and`/`or`/`not` — there is no `&&`, `||`, or `!` for boolean logic (`!` is reserved for Result/Option propagation below). `and`/`or` short-circuit; `not` binds tighter than `and`, which binds tighter than `or`. Conditions must be `bool`; there is no truthiness. `if`/`else` can also be used as an expression: `let label = if ready { "yes" } else { "no" }`. Strings use double quotes; no interpolation.

Record types: `type Point { x: int y: int }`, constructed with every field named exactly once, in any order: `Point(x: 1, y: 2)`. Access fields with `.`, chained directly onto any expression including a call's own result: `make_point(5).x`. Update immutably with `with`: `p with { x: p.x + 1 }`.

Enum types: `enum Shape { circle(radius: int) square(side: int) }`, constructed `Shape.circle(radius: 2)`. Match every variant exhaustively: `match shape { circle(radius) => ... square(side) => ... }`; payload bindings are typed and arm-local. `Option<T>` (`Some(value: T)` / `None`) and `Result<T, E>` (`Ok(value: T)` / `Err(error: E)`) are built-in enums, matched the same way — there is no `?` postfix sugar and no `??` operator, write `Option<T>` explicitly.

A function can also spell a fallible return type as `T ! E` where `E` is `str` (sugar for the same runtime `Result<T, E>` value): `fn load(path: str) -> str ! str`. Use postfix `?` (or the compatibility spelling `!`) only inside another result-returning function, to unwrap success or propagate failure immediately. Construct results with `result.ok(value)`/`result.err(message)` (shorthand) or `Result.Ok(value: ...)`/`Result.Err(error: ...)` (any error type) — both produce the same value, freely matchable and interchangeable with `result.is_ok`/`result.value`/`result.error`. There is no `try`/`catch`.

Generics: functions, records, and enums accept type parameters inferred at the call site, e.g. `fn identity<T>(value: T) -> T`. Constrain a parameter with a built-in marker protocol (`T: Eq`, `T: Ord`, `T: Number`, `T: Text`) or a user-declared one: `protocol Named {}` then `impl Named for User {}` (both bodies must be empty — markers only, no methods, no dynamic dispatch), then `fn greet<T: Named>(value: T) -> str`. Call a protocol-qualified static method as `User.name(user)`.

Closures and named function references (`&name`) may only appear as the direct, inline argument to `list.map`, `list.filter`, `list.find`, or `list.fold` — they cannot be bound to a `let` and called later, or stored in a field. Inline form: `fn(value: int) -> int => value + offset`; parameter and return types are required, and a closure may capture an enclosing `let` (never a `var`).

Modules: one file is one module. `use app.math` at the top of a file (before any other code) reads `app/math.lume` relative to the *importing file's own directory* and splices its source in; there is no `use ... as` aliasing. A qualified-looking function name (`math.square`) is just a naming convention, not an enforced namespace — record and enum names must be unique across the whole reachable import graph.

Common built-ins (run `lume api` for the complete list with arities):

```text
args.count/0  args.get/1
fs.exists/1  fs.read_text/1  fs.write_text/2  fs.try_read_text/1  fs.try_write_text/2
env.get/1  env.has/1  env.set/2  env.unset/1
process.run/2  process.ok/1  process.code/1  process.stdout/1  process.stderr/1
str.len/1  str.trim/1  str.upper/1  str.lower/1  str.from_int/1  str.to_int/1
str.contains/2  str.starts_with/2  str.ends_with/2
json.valid/1  json.get/2  json.encode/1
list.len/1  list.get/2  list.push/2  list.map/2  list.filter/2  list.find/2  list.fold/3
map.new/0  map.get/2  map.set/3  map.has/2  map.remove/2  map.keys/1  map.values/1
result.ok/1  result.err/1  result.is_ok/1  result.value/1  result.error/1  result.to_result/1
```

Native tests: `test "name" { expect.equal(actual, expected) }`; available assertions are `equal`, `true`, `some`, `ok`, `err`, plus `exit_code`/`stdout_contains`/`stderr_contains` for a `process.run` result. Run with `lume test file.lume`, optionally followed by `--filter text`; a directory discovers `*_test.lume` files recursively.

Use two-space indentation, braces, one statement per line, and no semicolons. Do not use methods with hidden dispatch, exceptions, operator overloading, macros, null, `for`/`break`/`continue`, or first-class function values outside a `list.*` callback slot — none of these exist in the language.
