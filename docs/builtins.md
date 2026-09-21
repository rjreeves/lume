# Lume Builtin Reference

Generated from `builtinNames()`/`builtinCounts()` in `src/lume.cto` (the same source `lume api` reads) by `lume api-docs` - do not hand-edit; regenerated on every build. For usage and semantics, see `docs/using-lume-the-fast-one.md`.

## args

- `args.count` - 0 argument(s)
- `args.get` - 1 argument(s)

## fs

- `fs.exists` - 1 argument(s)
- `fs.read_text` - 1 argument(s)
- `fs.write_text` - 2 argument(s)
- `fs.try_read_text` - 1 argument(s)
- `fs.try_write_text` - 2 argument(s)
- `fs.read_bytes` - 1 argument(s)
- `fs.write_bytes` - 2 argument(s)

## env

- `env.get` - 1 argument(s)
- `env.has` - 1 argument(s)
- `env.set` - 2 argument(s)
- `env.unset` - 1 argument(s)

## process

- `process.run` - 2 argument(s)
- `process.run_with_input` - 3 argument(s)
- `process.run_with_env` - 3 argument(s)
- `process.run_with_options` - 4 argument(s)
- `process.code` - 1 argument(s)
- `process.stdout` - 1 argument(s)
- `process.stderr` - 1 argument(s)
- `process.ok` - 1 argument(s)

## str

- `str.len` - 1 argument(s)
- `str.trim` - 1 argument(s)
- `str.upper` - 1 argument(s)
- `str.lower` - 1 argument(s)
- `str.from_int` - 1 argument(s)
- `str.to_int` - 1 argument(s)
- `str.contains` - 2 argument(s)
- `str.starts_with` - 2 argument(s)
- `str.ends_with` - 2 argument(s)

## json

- `json.valid` - 1 argument(s)
- `json.get` - 2 argument(s)
- `json.encode` - 1 argument(s)

## path

- `path.join` - 2 argument(s)
- `path.basename` - 1 argument(s)
- `path.dirname` - 1 argument(s)
- `path.extension` - 1 argument(s)
- `path.stem` - 1 argument(s)

## dir

- `dir.list` - 1 argument(s)
- `dir.walk` - 2 argument(s)

## time

- `time.now` - 0 argument(s)
- `time.to_iso` - 1 argument(s)
- `time.year` - 1 argument(s)
- `time.month` - 1 argument(s)
- `time.day` - 1 argument(s)
- `time.hour` - 1 argument(s)
- `time.minute` - 1 argument(s)
- `time.second` - 1 argument(s)
- `time.format` - 2 argument(s)
- `time.in_timezone` - 2 argument(s)
- `time.format_in_timezone` - 3 argument(s)

## duration

- `duration.seconds` - 1 argument(s)
- `duration.minutes` - 1 argument(s)
- `duration.hours` - 1 argument(s)
- `duration.days` - 1 argument(s)

## Duration

- `Duration.of_seconds` - 1 argument(s)
- `Duration.of_minutes` - 1 argument(s)
- `Duration.of_hours` - 1 argument(s)
- `Duration.of_days` - 1 argument(s)
- `Duration.add` - 2 argument(s)
- `Duration.sub` - 2 argument(s)
- `Duration.scale` - 2 argument(s)
- `Duration.to_seconds` - 1 argument(s)

## http

- `http.get` - 1 argument(s)
- `http.post` - 3 argument(s)
- `http.put` - 3 argument(s)
- `http.delete` - 1 argument(s)
- `http.request` - 4 argument(s)
- `http.request_with_limit` - 5 argument(s)
- `http.request_bytes` - 4 argument(s)
- `http.status` - 1 argument(s)
- `http.body` - 1 argument(s)
- `http.content_type` - 1 argument(s)
- `http.ok` - 1 argument(s)
- `http.body_bytes` - 1 argument(s)
- `http.truncated` - 1 argument(s)

## list

- `list.len` - 1 argument(s)
- `list.get` - 2 argument(s)
- `list.push` - 2 argument(s)
- `list.map` - 2 argument(s)
- `list.filter` - 2 argument(s)
- `list.find` - 2 argument(s)
- `list.fold` - 3 argument(s)

## map

- `map.new` - 0 argument(s)
- `map.len` - 1 argument(s)
- `map.get` - 2 argument(s)
- `map.has` - 2 argument(s)
- `map.set` - 3 argument(s)
- `map.remove` - 2 argument(s)
- `map.keys` - 1 argument(s)
- `map.values` - 1 argument(s)
- `map.map` - 2 argument(s)
- `map.filter` - 2 argument(s)
- `map.fold` - 3 argument(s)

## result

- `result.ok` - 1 argument(s)
- `result.err` - 1 argument(s)
- `result.is_ok` - 1 argument(s)
- `result.value` - 1 argument(s)
- `result.error` - 1 argument(s)
- `result.to_result` - 1 argument(s)

## fixture

- `fixture.temp_dir` - 0 argument(s)
- `fixture.cleanup` - 1 argument(s)

## bytes

- `bytes.from_str` - 1 argument(s)
- `bytes.to_str` - 1 argument(s)
- `bytes.length` - 1 argument(s)

## expect

- `expect.equal` - 2 argument(s)
- `expect.true` - 1 argument(s)
- `expect.ok` - 1 argument(s)
- `expect.err` - 1 argument(s)
- `expect.some` - 1 argument(s)
- `expect.exit_code` - 2 argument(s)
- `expect.stdout_contains` - 2 argument(s)
- `expect.stderr_contains` - 2 argument(s)

