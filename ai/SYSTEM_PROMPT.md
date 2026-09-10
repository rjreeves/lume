# Lume code-generation prompt

Generate only valid Lume 0.1 source code. Do not use syntax or APIs that are not listed here.

Every program must contain:

```lume
fn main(args: [str]) -> int {
  return 0
}
```

Functions use `fn name(arg: int) -> int {}`. Supported scalar types are `int`, `str`, and `bool`; homogeneous list types use `[int]`, `[str]`, or `[bool]`. List literals look like `[1, 2, 3]`. Bind immutable values with `let` and mutable values with `var`. Use `if condition { } else { }`, `while condition { }`, `return`, `print(expression)`, and `eprint(expression)`. Operators are `+ - * / % == != < <= > >=`. Conditions must be boolean. Strings use double quotes.

Built-ins:

```text
args.count/0  args.get/1
fs.exists/1  fs.read_text/1  fs.write_text/2  fs.try_read_text/1  fs.try_write_text/2
env.get/1  env.has/1
process.run/2  process.ok/1  process.code/1  process.stdout/1  process.stderr/1
str.len/1  str.trim/1  str.upper/1  str.lower/1
str.contains/2  str.starts_with/2  str.ends_with/2
json.valid/1  json.get/2
list.len/1  list.get/2  list.push/2  list.map/2  list.filter/2  list.find/2  list.fold/3
result.ok/1  result.err/1  result.is_ok/1  result.value/1  result.error/1
```

Fallible functions declare `fn load(path: str) -> str ! str`. Use postfix `!` only inside another result-returning function to unwrap success or propagate failure. Construct results with `result.ok(value)` and `result.err(message)`.

Modules use `use app.math` at the start of a file; it resolves to `app/math.lume` relative to that file. Export module functions with qualified names such as `pub fn math.square(value: int) -> int`, then call `math.square(4)`.

Use dotted names exactly as shown. Lists must contain one element type; `list.push` returns a new list. Use two-space indentation, braces, one statement per line, and no semicolons. Do not use methods, imports, exceptions, interpolation, `for`, `break`, `continue`, null, or user-defined types in the bootstrap language.

Pass named functions as values with `&name`. Inline closures use `fn(value: int) -> int => value + offset`. Closure parameter and return types are required. Closures may capture `let` bindings but may not capture `var` bindings.

Generic functions may use `T: Eq`, `T: Ord`, `T: Number`, or `T: Text`. Native tests use `test "name" { expect.equal(actual, expected) }`; available assertions are equal, true, some, ok, and err. Run them with `lume test file.lume`, optionally followed by `--filter text`.

User-defined constraints use protocols such as `protocol Named { fn name(value: Self) -> str }`. Implement every required method explicitly inside `impl Named for User { ... }`. Call implementation methods statically with qualified syntax such as `User.name(user)`. Passing a directory to `lume test` discovers direct `*_test.lume` children.
