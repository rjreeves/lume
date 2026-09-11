# Lume design philosophy

Lume is a focused, statically checked alternative to shell and Python for
automation, data transformation, command orchestration, and small tools.

Its guiding rule is:

> Add the smallest statically checked feature that makes real automation
> clearer, safer, or easier for AI to generate—without compromising fast,
> predictable compilation.

## What guides the language

New features should come from demonstrated needs:

- a real shell or Python task is fragile or unnecessarily verbose;
- static checking can prevent a common scripting failure;
- AI repeatedly generates the same mistake or ambiguous pattern;
- useful automation is blocked by a missing ecosystem capability.

Prefer explicit boundaries, canonical syntax, `Option` and `Result`, static
dispatch, type-erased generics, predictable `noun.verb` APIs, and diagnostics
that explain the exact correction.

Avoid global inference, implicit coercions, truthiness, exceptions, operator
overloading, macros, dynamic dispatch, and multiple equivalent ways to express
the same operation.

## Feature test

Before adding a language feature, ask:

1. Does it solve a frequent, demonstrated automation problem?
2. Can a library function solve it without new syntax?
3. Can the compiler check it locally and produce a precise error?
4. Is there one obvious way for people and AI to write it?
5. Does it preserve linear compilation and a small specification?
6. Does it improve measured task success enough to justify its cost?

If the answers are unclear, keep the feature outside the core until evidence
exists.

## Acceptance

Every accepted feature needs:

- representative programs and negative type-checking tests;
- documentation and a machine-readable API-manifest update;
- a before-and-after compiler benchmark;
- an AI evaluation task when the feature affects generated code.

The benchmark gates are defined in [`BENCHMARKS.md`](BENCHMARKS.md). Planned
work belongs in [`ROADMAP.md`](ROADMAP.md), implemented behavior in
[`ai/lume-api.json`](ai/lume-api.json), and language details in
[`SPEC.md`](SPEC.md).

The final product test is simple: **does this make Lume better at replacing a
real shell or Python script?** If not, it probably does not belong in Lume yet.
