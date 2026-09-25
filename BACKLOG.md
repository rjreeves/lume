# Lume backlog

Confirmed gaps between what `SPEC.md`/`README.md` claim and what the
bootstrap compiler (`src/lume.cto`) actually does — found by compiling and
running real probe programs against `dist\lume.exe`, not by inspection
alone, mirroring the standard `SPEC.md`'s own "Reconciliation note" already
holds itself to. Each item below is root-caused with a minimal reproduction
and the exact compiler output, at commit `e7788cd` (`ai/lume-api.json`
`version: 0.1.0-bootstrap`).

## Pending

### 8. `T?` (`Option<T>` postfix sugar) silently corrupts the parse of everything after it instead of being rejected

Found live while hunting for a new backlog item after item 7 shipped -
checking whether `T?`, the other bootstrap gap grouped alongside `??`
on the same §19 line, actually behaves the way SPEC.md's opening
Reconciliation Note promises. At commit `1e60318`
(`ai/lume-api.json` `version: 0.1.0-bootstrap`).

**Claim contradicted:** the same Reconciliation Note items 4/6/7 all
cite: "not yet implemented" syntax "will parse-error or type-error
today." §1 lists `T?` postfix sugar for `Option<T>` exactly this way.
In a *return-type* position this is item 7's own silent-no-op pattern
again (the `?` is dropped, `int?` is silently treated as plain `int`);
in a *parameter-type* position it's categorically worse - not a no-op,
active corruption that misparses an unbounded amount of subsequent
source, producing wildly incorrect, unrelated-looking errors with no
connection to the real mistake.

**Reproduction (parameter position - the severe case):**

```lume
fn identity(x: int?) -> int {
  return 0
}

fn main(args: [str]) -> int {
  print(identity(5))
  return 0
}
```

```
$ lume check repro.lume --json
{"code":"E0217","severity":"error","file":"repro.lume","line":6,"message":"function `identity` expects 7 arguments, got 1"}
```

`identity` takes exactly one declared parameter; the reported "7" is
not a real count of anything. Confirmed by varying unrelated,
downstream file content: inserting one extra unrelated function before
`main` (same `x: int?` signature, otherwise unrelated) changes the
reported count from 7 to 6 - proof this number is an artifact of where
the parser happens to resynchronize, not a meaningful arity. A third
variant (`x: int?, y: int, z: int)`, called with three arguments)
fails differently again, with `E0210 undefined binding \`y\`` *inside
the function body* - `y` and `z` are declared parameters, but the
corruption already consumed them as bogus type information before the
body was ever reached, so they were never actually registered as
bindings.

**Reproduction (return-type position - the quieter case):**

```lume
fn giveOption() -> int? {
  return Option.Some(value: 5)
}
```

```
$ lume check repro2.lume --json
{"code":"E0618","severity":"error","file":"repro2.lume","line":2,"message":"return type mismatch; expected int, got Option<int>"}
```

"expected int" confirms `int?`'s `?` was silently dropped rather than
rejected or understood - the declared return type is treated as plain
`int`, matching item 7's exact silent-no-op shape for a different
"not yet implemented" claim.

Root cause, confirmed by reading `typeNext` (`src/lume.cto`) directly -
the one function both `parameterTypes` and `functionReturnType` use to
find where a type annotation ends: it has cases for a bare name
(`start + 1`), a `[...]` list type (recurses), and a `<...>` generic
(scans to the matching `>`), but *no* case for a trailing `?` - it
falls through to the plain `start + 1` branch, landing exactly on the
`?` token itself rather than past it. In `functionReturnType` this only
truncates the extracted type text (the lone caller of `typeAt`/
`typeNext` there, no loop) - the quieter, item-7-shaped bug. In
`parameterTypes`'s per-parameter `while` loop, that one-token-short
position is far worse: the loop's own `,`/`)` boundary checks (looking
for a comma to continue, or a `)` to stop) both run against a value
that's still sitting on `?`, neither matches, so the loop treats `?`
as the start of *another* parameter, pushes a bogus `"unknown"` type,
advances past the *real* `)`, and keeps recursing into subsequent
tokens (the function body, the next declaration, whatever comes next)
as further bogus parameters until the drifting index happens to land
on some unrelated `)` later in the file - the closing paren of a
different function's own parameter list, in both reproductions above.

**Impact:** the most severe class of gap in this backlog - items 4/6
fail loudly but precisely, item 7 fails silently but locally (one
string, one wrong value), this one fails silently-or-loudly
*unpredictably*, and when it does fail loudly the error points
somewhere else in the file entirely, actively misleading whoever (human
or AI) is trying to fix it. Unlike items 4/6/7, this isn't scoped to
the one line containing the mistake - the blast radius depends on
wherever a `)` next happens to occur in the source, which could be
the very next function, or much further away in a larger file.

**Suggested fix:** give `typeNext` an explicit case for a trailing `?`
immediately after a type name (`start + 1` becoming `start + 2` when
the following token is `?`, mirroring how it already special-cases
`[` and `<`) - the minimum fix, matching item 7's approach, is to keep
`T?` rejected with a real diagnostic ("`T?` postfix sugar is not yet
implemented - write `Option<T>` explicitly", SPEC.md's own suggested
wording) rather than letting `typeNext` under-advance at all. That
alone would turn both reproductions above into one precise, correctly
-located error instead of either a silent wrong type or a cascading
misparse.

## Resolved

### 7. String interpolation silently does nothing instead of parse-/type-erroring, contradicting SPEC.md's own "Reconciliation note" guarantee

**Resolved:** `parseAtom` (`src/lume.cto`) - the one point every string
literal token becomes an expression - now checks the token's own
decoded text with a new `stringLooksInterpolated` helper (`{`
immediately followed by one or more identifier-like bytes immediately
followed by `}` - the exact `{name}` shape SPEC.md's own example uses)
and reports a dedicated `E0751` instead of silently accepting it as an
ordinary string constant. Deliberately *not* fixed in `scanString` (the
lexer) as originally suggested below: confirmed live that a lexer-level
`error`-kind token's own message never actually reaches the final
diagnostic - the *pre-existing* `E0002 unterminated string` case has
the identical problem, always surfacing as a generic `E0101` instead
(neither documented nor tested anywhere as the expected code, so not
its own separate backlog item, but worth recording here since it's
exactly the trap this fix's first attempt fell into). Moving the check
to `parseAtom`, where a working precise diagnostic (items 4's `E0749`,
6's `E0750`) is already proven to reach the user via `expressionError`,
sidesteps it entirely. Verified against this item's own two
reproductions below (both now report `E0751` with a correct line
number), plus that a string with literal, non-interpolation-shaped
braces (`"{1, 2, 3}"`, `"config: { key: value }"`, `"empty: {}"`) is
left alone - and that the full existing suite, which uses hundreds of
ordinary string literals throughout, passes unchanged, confirming the
narrow `{name}`-shape check doesn't false-positive anywhere in real
usage. Checked in as `examples/invalid_string_interpolation.lume`,
`examples/literal_braces_in_string.lume`, and test.ps1's "string
interpolation reports a precise hint" and "literal ... braces ... not
flagged" cases.

Found live while hunting for a new backlog item after item 6 shipped -
checking whether other "not yet implemented" items actually behave the
way the spec's own opening note promises, not by inspection alone. At
commit `971e896` (`ai/lume-api.json` `version: 0.1.0-bootstrap`).

**Claim contradicted:** `SPEC.md`'s own opening "Reconciliation note"
(the document's load-bearing promise about every other claim in it):
"Anything below marked **not yet implemented** is real, aspirational
syntax that **will parse-error or type-error today**." §2 marks string
interpolation exactly this way: "**String interpolation (`\"hello,
{name}\"`) is not yet implemented**." The note's own guarantee simply
does not hold for this one item - it neither parse-errors nor
type-errors; it silently compiles and runs, producing output that
looks nothing like what the source suggests.

**Reproduction (SPEC.md §2's own literal example):**

```lume
fn main(args: [str]) -> int {
  let name = "world"
  print("hello, {name}")
  return 0
}
```

```
$ lume check repro.lume --json
ok
$ lume run repro.lume
hello, {name}
```

No error at either `check` or `run` time. Confirmed this isn't a
"happens to look plausible" coincidence, not real interpolation: a
string referencing a name that doesn't exist anywhere in the program
(`"value: {totallyUndefinedNameXYZ}"`) *also* reports `ok` and runs
without complaint, and a string with multiple placeholders
(`"{a} + {b} = {a}"`) prints the braces and names back literally,
unchanged - nothing ever attempts to resolve or substitute anything
inside `{...}`.

Root cause, confirmed by reading the lexer directly: `scanString`
(`src/lume.cto`) only special-cases two byte values while scanning a
string literal's contents - `"` (34, the closing quote) and `\` (92,
the start of an escape sequence). Every other byte, `{`/`}` included,
falls through to the plain `else { index = index + 1 }` branch and
becomes ordinary literal content in the resulting `string` token. There
is no code path that recognizes `{...}` as anything special to reject
- the omission isn't a rejected-but-caught case, interpolation syntax
is simply never looked for at all, so nothing downstream ever has a
chance to error on it either.

For contrast, the *sibling* claim on the very same SPEC.md line
("Raw backtick strings are not yet implemented either") behaves exactly
as the Reconciliation Note promises - `` `raw string` `` genuinely
parse-errors (`E0101 expected expression`), because a lone `` ` ``
isn't a token `scanString`'s caller (the lexer's main dispatch) ever
enters string-scanning mode for in the first place. Interpolation is
the one claim on this exact line where the promise doesn't hold, not
a spec-wide problem.

**Impact:** the most severe class of gap in this backlog so far - items
4 and 6 at least *fail loudly*, giving a human or AI a compile error to
react to, however unhelpful the message. This one fails silently: a
program using `"hello, {name}"` compiles clean, runs, and produces
output that is superficially string-shaped, giving no signal
whatsoever that the interpolation never happened. For an AI generating
code from the language's own stated top-level principle ("reliable AI
generation"), this is a strictly worse failure mode than a rejected
program - a rejected program gets fixed before it ships; this one
ships silently wrong, and would only be caught by a human actually
reading the *printed output* character-by-character, not by anything
the compiler or type checker does.

**Suggested fix:** ~~either give `scanString` a real check for `{`/`}`
inside a string literal and reject it with a specific diagnostic
("string interpolation is not yet implemented - use `+` concatenation
instead", mirroring items 4/6's own precise-diagnostic pattern) - the
minimum needed to make the Reconciliation Note's guarantee actually
hold for this item - or, if silently treating `{...}` as literal text
is considered acceptable indefinitely, narrow the Reconciliation Note's
own wording so it no longer promises something untrue for at least one
of the items it covers.~~ Took the first option, though not literally
in `scanString` - see the `**Resolved**` note above for why the check
ended up in `parseAtom` instead.

### 6. `??` (Certo's own Option/Result-default operator, not Lume's) reports a generic, position-dependent parse error with no hint of the actual mistake

**Resolved:** `parsePrimary` (`src/lume.cto`) - the one place that
already consumes a postfix `?`/`!` and knows what token immediately
follows it - now checks for that following token also being `?` right
where the first one is consumed, and reports a dedicated `E0750`
("`` `??` is not a Lume operator; use `match` to provide a default for
`Option`/`Result` ``", with a line number) instead of leaving the
second `?` orphaned to fail generically and inconsistently three call
frames up (`E0206` or `E0207` depending on position - see below).
Deliberately the diagnostic-only fix, matching item 4's own precedent,
not the larger "add real unwrap-or-default sugar" question this item's
own Suggested-fix section raised - left open as a separate, later
design decision. Verified against this item's own two reproductions
below (both now report the identical `E0750 line 2`, no longer two
different codes depending on where `??` sits), plus that a genuine
single-`?` propagate (inside a `! `-returning function) is unaffected,
checked in as `examples/invalid_double_question_mark.lume` and
test.ps1's "`` `??` is not a Lume operator ``" case.

Found live while probing `path.extension`/`path.stem` edge cases for a
different check (looking for a new backlog item after item 4 shipped)
- found by an AI (this assistant) making essentially the same class of
mistake item 4 already covers, for a *different* Certo operator, not
by inspection. At commit `260dd1e` (`ai/lume-api.json`
`version: 0.1.0-bootstrap`).

**Claim contradicted:** none directly - Lume has no `??` operator and
`SPEC.md` never claims one. The gap is the same category item 4
already established as real: an ergonomic trap for a language whose
own stated top-level principle is "reliable AI generation," this time
for the *other* Certo operator someone who's just been reading or
writing Certo (this compiler's own implementation language, which uses
`??` as its Option-default operator - see e.g. `src/lume.cto`'s own
`gitCacheRoot`/`tempDirPath`) is naturally likely to reach for.

**Reproduction:**

```lume
fn main(args: [str]) -> int {
  let x = path.extension("noext") ?? "default"
  print(x)
  return 0
}
```

```
$ lume check repro.lume --json
{"code":"E0207","severity":"error","file":"repro.lume","line":2,"message":"unsupported statement `?`"}
```

Root cause, confirmed by bisection (`5 ?? 10` alone reproduces it - not
specific to `path.extension`, `Option`, or any particular type): Lume's
own `?`/`!` result-propagation operator (§9) is a *postfix, single-use*
operator - `parsePrimary`'s postfix check (`src/lume.cto`) consumes at
most one `?`/`!` per expression, not a loop. `x ??` therefore lexes and
parses as `(x ?)` followed by a second, now-orphaned `?` token with
nothing before it to attach to. What happens to that orphaned `?` is
*position-dependent*, unlike item 4's single, consistent `E0101`:
- At statement level (`let x = 5 ?? 10`), the first `?` completes the
  `let` statement, and the second `?` is left to start a new statement
  - never a valid statement-starting token - giving `E0207 unsupported
  statement \`?\``.
- Inside a call's argument list (`print(5 ?? 10)`), the first `?`
  completes the argument, and the argument-list parser then expects
  `,` or `)` and finds `?` instead, giving the unrelated-looking
  `E0206 expected \`)\``.

Two different generic codes for the identical underlying mistake,
neither mentioning `?` at all in a way that points at `??` specifically.

**Impact:** unlike item 4 (a `+`-vs-`++` mistake with an easy, already-
idiomatic replacement, plain `+`), this one has no direct Lume
equivalent to suggest reaching for instead - Lume's *only* way to
extract an `Option<T>`/`Result<T, E>` value with a fallback is an
explicit exhaustive `match` (§6, §9); there is no `unwrap_or`-shaped
builtin or operator anywhere in the documented API surface (confirmed:
no such name appears in `SPEC.md` or the real `lume api` builtin list).
"Give me a default if this is empty" is an extremely common operation
on exactly the two types (`Option`/`Result`) this language's own
stdlib returns constantly (`path.extension`, `dir.list`, `map.get`,
every `result.*` builtin) - so this is a likely mistake for anyone
coming from Certo (or Rust, Kotlin, C#, Swift, JS - `??` means the same
thing in all of them) to make repeatedly, not a one-off.

**Suggested fix:** ~~at minimum, the same class of fix as item 4 - a
cheap, specific check in `parsePrimary`'s postfix handling (or right
after it) for a second `?`/`!` immediately following the first, and a
dedicated diagnostic ("`??` is not a Lume operator; use an explicit
\`match\` to provide a default", or similar) instead of falling through
to either generic code.~~ Took exactly this fix. The larger question
this section also raised - whether the deeper gap (no `unwrap_or`-
shaped sugar at all) is worth closing on its own - is deliberately left
open, not folded into this fix; a real design decision, not a
diagnostics-quality bug, and outside this item's own scope.

### 4. `++` (Certo's own concatenation operator, not Lume's) reports a generic `E0101 expected expression` with no hint of the actual mistake

**Resolved:** `parseAdd` (`src/lume.cto`) - the one place that already
consumes a binary `+`/`-` and knows what token immediately follows it -
now checks for that immediately-following token also being `+` before
recursing into `parseMultiply` for the right-hand operand, and reports
a dedicated `E0749` ("`` `++` is not a Lume operator; use `+` for
concatenation ``", with a line number) instead of falling through three
levels down into `parseAtom`'s context-free `E0101` fallback. Verified
against this item's own reproduction below (now reports `E0749 line 2`
instead of `E0101 line 0`), plus that ordinary `+` concatenation and
`-` subtraction are both unaffected, checked in as
`examples/invalid_plus_plus_concatenation.lume` and test.ps1's
"`` `++` is not a Lume operator ``" case.

Found live while hand-writing a throwaway demo package to exercise the
git-based dependency feature (`{name, git, ref}`, shipped in #153) -
found by an AI (this assistant) making the exact mistake this item
warns about, not by inspection. At commit `741a7cb` (`ai/lume-api.json`
`version: 0.1.0-bootstrap`).

**Claim contradicted:** none directly - `SPEC.md` correctly documents
`+` as Lume's own concatenation operator and never mentions `++`. The
gap is the one ROADMAP.md's "Now: production scripting foundation"
section already calls out as a real category: an ergonomic trap for a
language whose own stated top-level principle is "reliable AI
generation" - the diagnostic gives no signal toward the actual
mistake, just a generic parse failure.

**Reproduction:**

```lume
fn hello(name: str) -> str {
  return "Hello, " ++ name
}

fn main(args: [str]) -> int {
  print(hello("world"))
  return 0
}
```

```
$ lume check repro.lume --json
{"code":"E0101","severity":"error","file":"repro.lume","line":0,"message":"expected expression"}
```

Root cause, confirmed by bisection (dropping to two operands, removing
the trailing `"!"`, and testing a non-dotted function name all still
reproduced it - it is neither the string content nor anything specific
to the dependency/module machinery this was first found through): `++`
is not a recognized token or operator anywhere in Lume's own grammar,
so `"Hello, " ++ name` lexes as two adjacent `+` tokens. The parser
consumes the first `+` as an ordinary binary operator expecting a
right-hand expression, then hits the second `+` in that position - not
a valid expression-starting token - and falls through to the same
generic "expected expression" fallback any other malformed expression
hits. `line: 0` compounds it, matching backlog item 1's own already-
noted "secondary diagnostics gap" for this exact code (`E0101`) - there
is no location to even look at.

**Impact:** `++` is Certo's own concatenation operator (`lume.cto`, the
compiler implementing Lume, is itself written in Certo), so it is a
natural, easy mistake for anyone - human or AI - who has just been
reading or writing Certo source to reach for reflexively in Lume code,
with the resulting error giving zero indication that's what happened.
ROADMAP.md's own "Status report" section already documents this exact
confusion actually occurring once before, while hand-writing the fixed
AI evaluation suite ("one task's first draft used `++` instead of
Lume's `+` for string concatenation") - that instance was caught and
fixed by a human/AI reviewer before being checked in, not by the
compiler, and no diagnostic follow-up was filed at the time. This is
the same mistake recurring, now with a reproduction on record.

**Suggested fix:** ~~give the lexer or parser a specific, cheap check for
this one confusable pattern - a `+` token immediately followed by
another `+` token where a binary operator was just consumed (the same
"precise diagnostic for a specific confusable case" pattern already
used for the `&T.method` gap, `E0740`, in ROADMAP.md's "Now" section) -
and report something like "`++` is not a Lume operator; use `+` for
concatenation" instead of falling through to the generic `E0101`.~~
Took exactly this fix, in `parseAdd` specifically (the point that
already has both the just-consumed operator and the following token in
hand, rather than reconstructing that context three levels down in
`parseAtom`). `E0101`'s own missing line number (flagged by backlog
item 1 for a different reproduction) is unaffected - still a separate,
still-open gap for every *other* generic parse failure.

### 5. `lume exec` never checked a `.lbc` artifact's own build hash, unlike the `run` cache it was built alongside

**Resolved:** `loadArtifact` (`src/lume.cto`, `exec`'s own loader - as
opposed to `decodeArtifact`, still deliberately lenient since
`compileOrCache`'s cache-hit/miss check needs to fall back to a
transparent recompile rather than error) now compares the decoded
artifact's `buildHash` against the running compiler's own
`compilerBuildHash()` and rejects a mismatch outright as a new
`E0406`, rather than the silent, incorrect-if-unlucky execution
confirmed below. Verified against this item's own reproduction (a
hand-corrupted `buildHash` byte range now reports `E0406` instead of
running), plus the full existing suite (including the sibling `run`
cache test just below it in `test.ps1`, confirming `compileOrCache`'s
own transparent-recompile behavior is unaffected - the fix lives
entirely in `loadArtifact`, which `compileOrCache` never calls),
checked in as `test.ps1`'s "exec rejects a foreign-build-hash
artifact" case.

Found live while confirming that a `.lbc` produced by `lume build` is
fully self-contained (splicing every `use`d module - including a
git-resolved dependency - into one combined source before compiling,
verified separately by deleting the original source entirely and
successfully `exec`ing the artifact from an otherwise-empty
directory). At commit `6f163a1` (`ai/lume-api.json`
`version: 0.1.0-bootstrap`).

**Claim contradicted:** ROADMAP.md's "Later: ecosystem readiness" >
"Distribution and interoperability" section marks "a stable bytecode
version and compatibility policy" as shipped (struck through), citing
exactly this mechanism: "`compileOrCache` ... keyed a cache hit purely
on the program's own source hash, with no way to tell 'this source is
unchanged' apart from 'this source is unchanged *and the compiler that
produced this bytecode is still the one running*' ... Fixed by
bumping the format to `LBC5` and embedding a build-time hash of
`lume.cto`'s own source ... either mismatch is now treated as a cache
miss." That fix is real, but it only covers `compileOrCache`, the
transparent same-machine cache behind `lume run`. `lume exec` - the
command that runs a standalone `.lbc` artifact, the one actually meant
to travel independently of its source (see the now-verified
self-containment above) - reads the identical `LBC5` header and
extracts the identical `buildHash` field, but never compares it
against anything. The roadmap bullet's own framing ("a stable bytecode
version and compatibility policy") reads as covering `.lbc` artifacts
generally, not "only when reached through the `run` cache specifically"
- the gap is real regardless of how the bullet is read, since `exec`
against a foreign-build artifact is exactly the scenario a
"compatibility policy" exists to guard.

**Reproduction:**

```lume
fn main(args: [str]) -> int {
  print(6 * 7)
  return 0
}
```

```
$ lume build app.lume app.lbc
wrote app.lbc
```

Hand-corrupting only the artifact's `buildHash` field (bytes
`[68, 132)` of the file, per `decodeArtifactHeader` - leaving the
`LBC5` magic, `sourceHash`, instruction count, and every instruction
byte untouched) and running the corrupted copy:

```
$ lume exec app_corrupted_buildhash.lbc
42
```

No error, no warning - it runs as if the build hash matched, because
nothing ever reads it back out of the decoded `ArtifactResult` on this
path. Compare `src/lume.cto`'s `loadArtifact` (`exec`'s own loader):
it calls `decodeArtifact` and only ever inspects the returned
`problem` field before executing - `sourceHash`/`buildHash` are
decoded into the result struct and then simply unused. The comparison
this claim describes (`Text.eq(header.buildHash, compilerBuildHash())`)
exists exactly once in the whole file, inside `compileOrCache`, which
`exec` never calls.

**Impact:** `lume build` producing a portable, source-independent
artifact is the one workflow where a compiler-version mismatch is
most likely to actually occur in practice - the artifact is
specifically meant to be kept or moved somewhere its original source
and compiler build are no longer both present to compare against.
`run`'s own cache degrades safely on a mismatch (falls back to a
transparent recompile from source, silently correct either way,
because the source is still right there). `exec` has no source to
fall back to - a real compiler-behavior change between the build that
produced an artifact and the `lume.exe` now executing it (a fixed
runtime bug, a changed opcode's semantics, anything `LBC5`'s own
introduction was written to guard against) would run silently and
incorrectly instead of being rejected, the opposite of what "a stable
bytecode version and compatibility policy" implies is guaranteed.

**Suggested fix:** ~~either give `exec`/`loadArtifact` the same
`compilerBuildHash()` comparison `compileOrCache` already has - failing
loudly (a new `E0NNN`) on a mismatch, since there's no live source to
silently fall back to recompiling from - or, if running a foreign-build
artifact is meant to stay permitted (e.g. deliberately, for a
long-lived deployed artifact nobody wants invalidated by every compiler
patch release), narrow ROADMAP.md's own claim to say so explicitly
rather than reading as covering `exec` too.~~ Took the first option.

### 1. Multi-line list literals fail to parse

**Resolved:** `parseListItems` (`src/lume.cto`) and `parseCallArguments`
(the one `(...)` argument-list parser every plain function call, record
construction, and enum variant construction all share) neither ever
called `skipNewlines`, unlike a `with`-update's own `{...}` field list,
which already tolerated newlines via three `skipNewlines` calls at the
points that matter: right after the opening bracket, right after each
parsed item (before checking for `,`), and right after consuming a `,`.
Fixed by porting that exact, already-proven pattern into both
functions - closing this item and the separate "multi-line call/
record-construction argument lists" gap `SPEC.md` §19 documented
alongside it, in one change. Also added the missing line number to
`E0104`'s own message, per this item's own "secondary diagnostics gap"
note below. Verified against this item's own reproduction (now passes),
a multi-line function call, a multi-line record construction, a
multi-line enum variant construction, an empty multi-line list (`[\n]`),
and a trailing item with no comma before the closing bracket - all now
compile and run correctly, checked in as `examples/multiline_list.lume`
and `examples/multiline_call_arguments.lume`.

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

**Resolved:** `callPure` (`src/lume.cto`) is a full, separate
bytecode-dispatch loop, not a sandboxed subset by design - there was no
compile-time check anywhere blocking `match` in a callback, just a
generic "unsupported operation" fallback hit because `match_start`/
`match_arm`/`match_arm_end`/`match_finish` were never ported over from
`execute()` (the main interpreter), which already supported them. Fixed
by porting them, following the exact same pattern `callPure`'s own
`decode_json` handling already used once before for an identical class
of gap. The one real wrinkle: `execute()`'s own variant-payload binding
(`bindVariantPayload`) depth-scopes binding names for its single shared
`variables` stack across recursive frames - `callPure` never needed
that (each invocation already has an isolated `variables`) and reusing
it as-is caused a real, confirmed-live regression (`callback binding
unavailable \`code\``) until split into an unscoped sibling,
`bindVariantPayloadUnscoped`. Verified against this item's own
reproduction below, which now passes, plus the transitivity case
(`list.map` calling a helper that itself uses `match`) and if-expression
(a related, same-class gap found alongside these two) - all three now
work inside both `test` bodies and `list.*`/`map.*` callbacks, checked
in as `examples/callback_match_propagate.lume`.

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

**Resolved:** same root cause and fix as item 2 above - `unwrap`/
`propagate` were never ported into `callPure`. The port turned out
*simpler* than `execute()`'s own version, not a straight copy:
`execute()` needs a `returnAddresses` stack to jump back across nested
calls sharing one flat loop, but `callPure` has no such mechanism
because a nested call is already a separate Certo function invocation.
On a propagate/unwrap failure, `callPure` now does what its own
`return`/`closure_end` handling already did - end the current
invocation early with the failed value as its own result - which the
caller (an outer `callPure` a level up, `list.map`'s own loop, or the
test runner) already knows how to handle. Verified against both
reproductions below (the direct `test`-body case and the transitive
`list.map` case), plus the success path (not just the failure path
both reproductions exercise) - all now pass.

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
