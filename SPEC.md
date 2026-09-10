# Lume language specification — draft 0.1

## 1. Principles

The language follows five rules:

1. There is one obvious representation for common code.
2. A file can be compiled with bounded local analysis.
3. Hidden control flow is forbidden.
4. Failure and absence are visible in types.
5. Tool output is stable enough for machines to consume.

## 2. Source model

- UTF-8 source files use the `.lume` extension.
- Newlines terminate statements except inside `()`, `[]`, or `{}`.
- Blocks use braces and must be formatted with two-space indentation.
- Line comments start with `//`. Documentation comments start with `///`.
- Identifiers are ASCII `snake_case`. Types are `PascalCase`.
- The formatter defines the only canonical layout.

## 3. Lexical grammar

```text
identifier  := [A-Za-z_][A-Za-z0-9_]*
int         := 0 | [1-9][0-9_]*
float       := int '.' [0-9_]+
string      := '"' character* '"'
comment     := '//' character* newline
```

Strings support `\n`, `\r`, `\t`, `\\`, `\"`, Unicode escapes, and `{expression}` interpolation. Raw strings use backticks and do not interpolate.

## 4. Built-in types

```text
bool int float str bytes unit never
[T]             list
{str: T}         string-keyed map
T?               optional value
T ! E            result: ok T or err E
fn(A, B) -> C    function
```

Integers are signed 64-bit. Floats are IEEE-754 binary64. Numeric widths do not vary by platform.

There are no implicit conversions except integer literals may initialize a `float` when exactly representable. Conversion functions such as `int.parse` and `str.from` are explicit.

## 5. Bindings

```lume
let name = "Ada"       // immutable; type inferred locally
let port: int = 5432   // annotation allowed
var retries = 3        // mutable
retries = retries - 1
```

Bindings cannot be shadowed in the same function. A variable must be definitely initialized before use.

## 6. Functions

```lume
fn add(a: int, b: int) -> int {
  return a + b
}
```

Parameter and return types are mandatory. Functions are not overloaded. Default and named arguments are omitted in version 0.1; they add call-resolution rules and multiple equivalent spellings.

The entry point is `fn main(args: [str]) -> int`. Top-level executable statements are forbidden.

## 7. Control flow

```lume
if score >= 80 {
  print("pass")
} else {
  print("retry")
}

for item in items {
  print(item)
}

while ready == false {
  poll()
}
```

Conditions must be `bool`; Lume has no truthiness. `break` and `continue` are valid only inside loops.

## 8. Data types

```lume
type User {
  id: int
  name: str
  email: str?
}

enum Status {
  pending
  running(started_at: int)
  failed(message: str)
  done
}
```

Records use named fields and enums use exhaustive pattern matching. There are no classes, inheritance, methods with hidden dispatch, or structural subtyping.

## 9. Absence and errors

`T?` contains `some T` or `none`. `T ! E` contains `ok T` or `err E`.

```lume
fn read_count(path: str) -> int ! str {
  let text = fs.read_text(path)!
  return int.parse(str.trim(text))!
}

let label = maybe_name ?? "anonymous"
```

Postfix `!` returns an error from the current function. It is legal only when the enclosing result type can carry the same error type. It never throws.

`match` is exhaustive:

```lume
match value {
  some item => print(item)
  none => print("missing")
}
```

## 10. Modules and packages

One file is one module. File paths determine module names; there is no module declaration.

```lume
use fs
use app.config
use app.user as user
```

Imports must appear first and cannot be dynamic. Circular imports are errors. A package lockfile maps import names directly to content-addressed package directories before the compiler starts, so compilation performs no network access or dependency solving.

Declarations are private by default. Prefix exported declarations with `pub`.

## 11. Standard library naming

APIs follow `noun.verb` consistently:

```text
str.len       str.split       str.trim
list.len      list.push       list.get
map.get       map.set         map.has
fs.read_text  fs.write_text   fs.exists
json.encode   json.decode
http.get      http.request
process.run   process.env     process.exit
time.now      time.sleep
```

I/O operations return result values. APIs do not throw exceptions.

## 12. Lightweight generic calls

The core containers and codecs may accept types with bracket syntax:

```lume
let users = json.decode[[User]](text)!
```

Generic functions, records, and enums are type-erased. A generic function may
use a built-in constraint such as `T: Eq`, `T: Ord`, `T: Number`, or `T: Text`.
Constraints are validated after call-site inference and do not generate a copy
of the function for each concrete type.

## 13. Concurrency

Concurrency is intentionally deferred from the core. A later version may add structured tasks with explicit `spawn` and `await`. Threads, async coloring, actors, and callbacks should not all coexist; the design must select one canonical model after measurement.

## 14. Grammar sketch

```text
file       := use_decl* declaration* EOF
declaration:= ('pub')? (function | record | enum | constant)
function   := 'fn' ident generic_params? '(' params? ')' '->' type block
generic_params := '<' generic_param (',' generic_param)* '>'
generic_param := ident (':' ('Eq' | 'Ord' | 'Number' | 'Text'))?
block      := '{' newline statement* '}'
statement  := let_stmt | var_stmt | assignment | if_stmt | while_stmt
            | for_stmt | match_stmt | return_stmt | break_stmt
            | continue_stmt | expression
expression := Pratt expression with fixed, non-overloadable operators
```

The complete grammar must remain LL(2) outside expressions. Expressions use a fixed Pratt precedence table.

## 15. Compiler pipeline

```text
source bytes
  -> declaration/import scan
  -> parse + local typecheck + register-bytecode emission
  -> verifier
  -> content-addressed cache
  -> VM
```

The declaration scan records names, signatures, and byte offsets without building function bodies. The second pass compiles each function independently. This enables parallel compilation for large modules and precise incremental caching.

The compiler should use:

- a hand-written byte lexer;
- string interning scoped to one compilation;
- arena allocation cleared at the end of a module;
- compact numeric type IDs;
- direct diagnostic spans as byte offsets;
- branch backpatching during bytecode emission;
- no retained full-program AST after emission.

## 16. Bytecode

Use a register VM to reduce instruction count and dispatch compared with a stack VM:

```text
load_const r0, #3
load_const r1, #4
add_int    r2, r0, r1
return     r2
```

Each function stores its register count, constants, instructions, result metadata, and a compressed source map. Bytecode is verified once before caching.

## 17. Diagnostics contract

Every diagnostic has a stable code, primary span, short message, and optional fix:

```text
E0214 examples/config.lume:8:14 expected `int`, found `str`
  fix: replace `port` with `int.parse(port)!`
```

The CLI supports both human text and newline-delimited JSON. AI tools should use JSON diagnostics and apply fixes by span rather than parsing prose.

## 18. Deliberate exclusions

The following are outside version 0.1:

- macros and metaprogramming;
- operator overloading;
- exceptions;
- implicit truthiness or coercion;
- inheritance;
- user-defined generics;
- borrow checking;
- compile-time execution;
- build scripts executed during compilation;
- multiple formatting styles.

Features may be added only if benchmarks show that their value exceeds their cost in compile time, language-model error rate, and specification size.
