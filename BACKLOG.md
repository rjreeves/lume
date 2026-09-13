# Lume backlog

Confirmed gaps between what `SPEC.md`/`README.md` claim and what the
bootstrap compiler (`src/lume.cto`) actually does — found by compiling and
running real probe programs against `dist\lume.exe`, not by inspection
alone, mirroring the standard `SPEC.md`'s own "Reconciliation note" already
holds itself to. Each item below is root-caused with a minimal reproduction
and the exact compiler output, at commit `e7788cd` (`ai/lume-api.json`
`version: 0.1.0-bootstrap`).

## Pending

### 1. Multi-line list literals fail to parse

**Claim contradicted:** `SPEC.md` §2 — "Newlines terminate statements
except inside `[]` or `{}`." List literals (`[]`) are one of only two
bracket forms called out as newline-tolerant, but any `[...]` list literal
spanning more than one line fails to parse, regardless of what it contains.

**Reproduction:**

```lume
fn main(args: [str]) -> int {
  let items = [
    1,
    2,
    3
  ]
  print(list.len(items))
  return 0
}
```

```
$ lume check probe.lume --json
{"code":"E0101","severity":"error","file":"probe.lume","line":0,"message":"expected expression"}
```

The identical list written on one line — `let items = [1, 2, 3]` — compiles
and runs correctly and prints `3`. Swapping the elements for function calls
(`[task("a", []), task("b", [])]`) makes no difference: it is the newline
inside `[...]`, not the element expressions, that the parser rejects. The
reported line (`0`) is also unhelpful for locating the failure in a larger
file — a secondary diagnostics gap worth fixing alongside this one.

**Impact:** forces every list literal with more than a couple of short
elements onto one long line, working against the language's own
readability goals. Found while building `examples/taskgraph_test.lume`
(PR #40): a handful of `Task(...)` fixtures for a graph test read far
worse crammed onto one 200+ column line than `SPEC.md` §2's own
`[]`-tolerates-newlines claim implies they should have to.

**Suggested fix:** either the lexer/parser should honor newlines inside
`[...]` the way it already does for a record/enum construction's `{...}`
field list (see `with` update blocks), or `SPEC.md` §2 and the §19 gap list
should be corrected to state plainly that multi-line list literals are not
yet supported, alongside the existing "multi-line call/record-construction
argument lists" entry.

### 2. `test` block bodies run through the same match-forbidding restricted evaluator as `list.*` callbacks, undocumented in §13

**Claim contradicted:** `SPEC.md` §19 already lists "`match` inside a
`list.*` callback's reachable call graph" as a known bootstrap gap, and §12
documents exactly what a callback body may and may not contain. **§13
(Testing) never cross-references this.** Its prose and grammar sketch
(`test := 'test' string '{' expect_call* '}'`) only imply a test body is a
sequence of `expect.*` calls — nothing states that the body (which in
practice also accepts `let`/`if`/`while`, matching a callback's own allowed
set) is evaluated by that identical restricted evaluator.

**Reproduction:**

```lume
enum Outcome {
  passed(code: int)
  failed(message: str)
}

fn classify(outcome: Outcome) -> int {
  return match outcome {
    passed(code) => code
    failed(message) => -1
  }
}

test "classifies an outcome" {
  expect.equal(classify(Outcome.passed(code: 7)), 7)
}

fn main(args: [str]) -> int {
  return 0
}
```

```
$ lume test repro.lume --json
{"event":"test","id":"repro.lume#classifies an outcome","name":"classifies an outcome","status":"fail","line":13,"message":"callback `classify` uses unsupported operation `match_start`"}
{"event":"summary","passed":0,"failed":1,"total":1}
```

`classify` is never passed to `list.map`/`filter`/`find`/`fold` — it is
called directly from the test body — yet the failure is the exact
"callback ... uses unsupported operation" wording documented for §12
callbacks specifically, at run time rather than compile time.

**Impact:** a significant, currently-undocumented testability gap. `match`
is the only way to inspect an enum, `Option<T>`, or the generic
`Result<T, E>` shape, so **no test can exercise any function whose call
graph touches an enum, `Option`, or generic `Result`** — in practice, most
non-trivial Lume code once records/enums are in use. This repository's own
examples already route around it without saying so: `examples/task_board`
ships no native tests at all, and PR #40's `examples/taskgraph_test.lume`
had to scope its coverage down to the match-free string/list helpers
underneath a much larger, match-heavy module, verifying the real behavior
(`graph.validate`/`order`/`transitive_closure`, `report.to_json`) via
`lume run` instead.

**Suggested fix:** either lift the restriction for `test` bodies
specifically — a test isn't compiled into the same reusable, optimized
runtime shape a `&name`/closure callback is, so the argument for
restricting callbacks (§12) may not carry over — or document this
cross-reference explicitly in `SPEC.md` §13 as a load-bearing limitation
instead of a silent run-time surprise, and update the grammar sketch to
reflect what a test body actually accepts.

### 3. `?`/`!` result propagation also fails inside the restricted evaluator, undocumented in §12

**Claim contradicted:** `SPEC.md` §12 lists exactly what a callback body
(and, per item 2 above, a `test` body) may contain: "Field access,
arithmetic, comparisons, `if`/`while`, calls to other user functions
(including recursively, transitively), calls to builtins, and `with`
record updates all work inside a callback. The one thing that still does
not work, anywhere in a callback's reachable call graph, is `match`." This
is incomplete — `?` (and its compatibility spelling `!`), §9's own
result-propagation operator, fails the exact same way, with no mention
anywhere in §12 or §19's gap list.

**Reproduction — inside a `test` block:**

```lume
fn upper_or_fail(text: str) -> str ! str {
  let trimmed = fs.try_read_text(text)?
  return result.ok(str.upper(trimmed))
}

test "propagates a shorthand result" {
  let outcome = upper_or_fail("does-not-exist.txt")
  expect.true(result.is_ok(outcome) == false)
}

fn main(args: [str]) -> int {
  return 0
}
```

```
$ lume test repro.lume --json
{"event":"test","id":"repro.lume#propagates a shorthand result","name":"propagates a shorthand result","status":"fail","line":6,"message":"callback `upper_or_fail` uses unsupported operation `propagate`"}
```

**And the restriction is not test-specific** — the identical failure
reproduces from an ordinary `list.map` callback, confirming this is §12's
restricted evaluator itself, not something particular to `test` bodies:

```lume
fn upper_or_fail(text: str) -> str ! str {
  let trimmed = fs.try_read_text(text)?
  return result.ok(str.upper(trimmed))
}

fn always_zero(text: str) -> int {
  let outcome = upper_or_fail(text)
  return 0
}

fn main(args: [str]) -> int {
  let mapped = list.map(["a.txt"], &always_zero)
  print(list.get(mapped, 0))
  return 0
}
```

```
$ lume run repro2.lume
callback `upper_or_fail` uses unsupported operation `propagate`
```

Note `always_zero` never uses `?` itself — the failing operation is in
`upper_or_fail`, called transitively, exactly matching how `match`
already fails transitively per §12's own existing wording for that case.

**Impact:** compounds item 2 above. Since `fs.try_read_text`,
`fs.try_write_text`, `Type.from_json`, and `json.encode` are exactly the
builtins that return the shorthand `T ! E` shape ordinary code is expected
to use `?` with (§9), **no test can exercise any function that propagates
one of those results with `?`/`!`**, in addition to the enum/match
restriction item 2 already covers. A function has to route around both
restrictions — no `match`, no `?` — anywhere in its reachable call graph
to be natively testable at all, which in practice rules out most
fallible, non-trivial Lume code. `examples/taskgraph/report.lume` (PR #40)
was rewritten to use `result.is_ok`/`result.value`/`result.error` instead
of `?` specifically so `report.to_json` could be covered by
`examples/taskgraph_test.lume`, rather than being routed around like
item 2's other examples.

**Suggested fix:** same as item 2 — either lift the restriction (for
`test` bodies, or for `?`/`!` specifically if `match` has a genuinely
different reason to stay restricted), or document §12's actual, complete
list of disallowed operations, and cross-reference it from §13.
