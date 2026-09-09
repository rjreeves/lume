# Benchmark contract

“Quickest” and “fastest for AI” are meaningless without reproducible measurements. Lume should be compared against Lua, Python, Go, TypeScript, Bun, and a small bytecode language on the same machine.

## Compiler measurements

Measure cold and warm runs separately:

- empty program latency;
- 100, 1,000, 10,000, and 100,000 lines;
- clean package build;
- one-function incremental rebuild;
- peak resident memory;
- emitted bytecode size;
- time to first user instruction.

Report median, p95, and standard deviation over at least 30 runs. Exclude process startup only in a separately labelled persistent-daemon test.

## AI generation measurements

Use a fixed suite of at least 100 tasks across CLI, JSON, HTTP, files, database access, transformations, and error handling. For each language and model, measure:

- input tokens needed to describe the language/API;
- output tokens on the first attempt;
- first-attempt parse rate;
- first-attempt typecheck rate;
- tests passed on the first attempt;
- repair turns and repair tokens;
- wall time to the first fully correct program.

The primary metric is:

```text
total model tokens / fully correct programs
```

Secondary metrics are median wall time to correctness and first-attempt success rate. All prompts, model versions, temperatures, tasks, and test harnesses must be published.

## Acceptance gates

A feature cannot enter the core language if it causes either:

- more than a 5% regression in median clean compile time; or
- more than a 3% regression in AI tokens-to-correctness;

unless it improves task success enough to offset the regression on the published suite.
# Real 10,000-line benchmark

Run the fixed-size compiler benchmark with:

```powershell
.\benchmark-10000.ps1
```

It generates one valid 10,000-line Lume program, validates it, warms the
compiler, and reports latency and source-lines per second across repeated runs.
The generated source is placed under `dist\`.

