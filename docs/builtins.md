# Lume Builtin Reference

Generated from `builtinDocs()` in `src/lume.cto` (the same source `lume api` reads) by `lume api-docs` - do not hand-edit; regenerated on every build. For usage and semantics, see `docs/using-lume-the-fast-one.md`.

## args

- `args.count() -> int`
  Number of command-line arguments, excluding the program name.
  Example: `args.count() // e.g. 2, if the program was run with two arguments`
- `args.get(index: int) -> str`
  The argument at `index`. Does not panic on an out-of-range index - it returns "" instead, the same way a missing environment variable does.
  Example: `args.get(0) // the first CLI argument, or "" if none was passed`

## fs

- `fs.exists(path: str) -> bool`
  Whether a *file* exists at `path` - file-only, not file-or-directory; returns false for a path that is genuinely an existing directory. Use dir.exists to check a directory instead.
  Example: `fs.exists("config.json") // true if it exists as a file`
- `fs.read_text(path: str) -> str`
  Reads a file's full contents as text.
  Example: `fs.read_text("notes.txt") // the file's contents`
  Errors: E0312 if the file can't be read.
- `fs.write_text(path: str, content: str) -> bool`
  Writes `content` to `path`, creating or overwriting it; the bool reports whether the write succeeded, so a failed write is reported, not panicked on.
  Example: `fs.write_text("out.txt", "hello") // true`
- `fs.try_read_text(path: str) -> result<str,str>`
  Reads a file's full contents as text, returning Err instead of failing on a read error.
  Example: `fs.try_read_text("notes.txt") // Ok("...") or Err("...")`
  Errors: Returns Err on failure; never panics.
- `fs.try_write_text(path: str, content: str) -> result<bool,str>`
  Writes `content` to `path`, returning Err instead of failing on a write error.
  Example: `fs.try_write_text("out.txt", "hello") // Ok(true) or Err("...")`
  Errors: Returns Err on failure; never panics.
- `fs.read_bytes(path: str) -> result<bytes,str>`
  Reads a file's full contents as raw bytes.
  Example: `fs.read_bytes("data.bin") // Ok(bytes) or Err("...")`
  Errors: Returns Err on failure; never panics.
- `fs.write_bytes(path: str, data: bytes) -> bool`
  Writes raw bytes to `path`, creating or overwriting it; the bool reports whether the write succeeded.
  Example: `fs.write_bytes("data.bin", data) // true`

## env

- `env.get(name: str) -> str`
  The environment variable's value, or "" if it isn't set - there is no way to tell "unset" apart from "set to the empty string" from this alone; use env.has first if that distinction matters.
  Example: `env.get("HOME") // e.g. "/home/ada", or "" if unset`
- `env.has(name: str) -> bool`
  Whether an environment variable is set, even to an empty value.
  Example: `env.has("CI") // true inside most CI environments`
- `env.set(name: str, value: str) -> bool`
  Sets an environment variable for the current process (and anything it later spawns via process.run, unless overridden by process.run_with_env).
  Example: `env.set("DEBUG", "1") // true`
- `env.unset(name: str) -> bool`
  Removes an environment variable from the current process.
  Example: `env.unset("DEBUG") // true`

## process

- `process.run(executable: str, arguments: [str]) -> process`
  Runs a process to completion and captures its exit code, stdout, and stderr. A failure to spawn the executable at all (e.g. it doesn't exist) is not distinguished from a timeout - both report exit code -1 through process.code.
  Example: `process.run("git", ["status"]) // a process result`
- `process.run_with_input(executable: str, arguments: [str], input: str) -> process`
  Like process.run, piping `input` to the child process's stdin.
  Example: `process.run_with_input("cat", [], "hi") // a process result with stdout "hi"`
- `process.run_with_env(executable: str, arguments: [str], env: Map<str,str>) -> process`
  Like process.run, with `env` overriding environment variables for the child process only - the current process's own environment is restored once the call returns.
  Example: `process.run_with_env("printenv", ["KEY"], map.set(map.new(), "KEY", "value")) // a process result with stdout "value"`
- `process.run_with_options(executable: str, arguments: [str], workingDir: str, timeoutMs: int) -> process`
  Like process.run, with a working directory ("" for unchanged) and an optional timeout in milliseconds (<= 0 for none); a timed-out process is killed and reports exit code -1, the same code a failed-to-spawn process reports.
  Example: `process.run_with_options("sleep", ["5"], "", 500) // killed at 500ms, exit code -1`
- `process.code(result: process) -> int`
  The child process's exit code (-1 for a timeout or a failed spawn).
  Example: `process.code(result) // 0 on success`
- `process.stdout(result: process) -> str`
  The child process's captured standard output.
  Example: `process.stdout(result) // the captured stdout text`
- `process.stderr(result: process) -> str`
  The child process's captured standard error.
  Example: `process.stderr(result) // the captured stderr text`
- `process.ok(result: process) -> bool`
  Whether the process exited with code 0.
  Example: `process.ok(result) // true if exit code was 0`

## str

- `str.len(value: str) -> int`
  Number of bytes in a string (not necessarily the number of visible characters, for non-ASCII text).
  Example: `str.len("hello") // 5`
- `str.trim(value: str) -> str`
  Removes leading and trailing whitespace.
  Example: `str.trim("  hi  ") // "hi"`
- `str.upper(value: str) -> str`
  Converts to uppercase.
  Example: `str.upper("hi") // "HI"`
- `str.lower(value: str) -> str`
  Converts to lowercase.
  Example: `str.lower("HI") // "hi"`
- `str.from_int(value: int) -> str`
  Formats an int as decimal text.
  Example: `str.from_int(42) // "42"`
- `str.to_int(value: str) -> result<int,str>`
  Parses decimal text as an int; Err if it isn't a valid integer.
  Example: `str.to_int("42") // Ok(42)`
  Errors: Returns Err on failure; never panics.
- `str.contains(haystack: str, needle: str) -> bool`
  Whether `haystack` contains `needle`.
  Example: `str.contains("hello", "ell") // true`
- `str.starts_with(value: str, prefix: str) -> bool`
  Whether `value` starts with `prefix`.
  Example: `str.starts_with("hello", "he") // true`
- `str.ends_with(value: str, suffix: str) -> bool`
  Whether `value` ends with `suffix`.
  Example: `str.ends_with("hello", "lo") // true`

## json

- `json.valid(text: str) -> bool`
  Whether `text` parses as valid JSON of any shape (object, array, or scalar) - does not require it to be an object the way json.get does.
  Example: `json.valid("{}") // true`
- `json.get(text: str, key: str) -> str`
  A top-level key's value from a JSON object, as text. There is no dotted/nested path support - only one flat, top-level key lookup.
  Example: `json.get("{\"a\":1}", "a") // "1"`
  Errors: E0313 if `text` doesn't decode as a JSON object.
- `json.encode(value: T) -> result<str,str>`
  Encodes a value (int/str/bool/list/record, recursively, plus enums including Option/Result) as a JSON string. Map is not supported and returns Err.
  Example: `json.encode(42) // Ok("42")`
  Errors: Returns Err on failure; never panics.

## path

- `path.join(a: str, b: str) -> str`
  Joins two path segments. Pure string concatenation with a separator - it does not special-case an absolute `b`, unlike some other languages' path-join.
  Example: `path.join("a", "b") // "a/b"`
- `path.basename(path: str) -> str`
  The final path component.
  Example: `path.basename("a/b.txt") // "b.txt"`
- `path.dirname(path: str) -> str`
  The path with its final component removed.
  Example: `path.dirname("a/b.txt") // "a"`
- `path.extension(path: str) -> Option<str>`
  The file extension, without the dot, or None if there isn't one.
  Example: `path.extension("a/b.txt") // Some("txt")`
- `path.stem(path: str) -> str`
  The final path component without its extension.
  Example: `path.stem("a/b.txt") // "b"`

## dir

- `dir.list(path: str) -> result<[str],str>`
  Lists a directory's immediate entries. Names only (not full paths), unsorted, and not recursive - see dir.walk for that.
  Example: `dir.list(".") // Ok(["a.lume", "b.lume"])`
  Errors: Returns Err on failure; never panics.
- `dir.walk(path: str, maxDepth: int) -> result<[str],str>`
  Recursively lists files under `path` as full paths, files only (a subdirectory is recursed into, never included in the result itself). `maxDepth` 0 means only `path`'s own files; an unreadable subdirectory partway through the walk is silently skipped, not a failure.
  Example: `dir.walk(".", 32) // Ok(["src/a.lume", "src/sub/b.lume"])`
  Errors: Returns Err on failure; never panics.
- `dir.exists(path: str) -> bool`
  Whether a directory exists at `path`. Complements fs.exists, which is file-only and returns false for a directory.
  Example: `dir.exists("src") // true if it exists as a directory`

## time

- `time.now() -> int`
  Current Unix epoch time in seconds.
  Example: `time.now() // e.g. 1735000000`
- `time.to_iso(seconds: int) -> str`
  Formats epoch seconds as a UTC ISO-8601 string.
  Example: `time.to_iso(0) // "1970-01-01T00:00:00Z"`
- `time.year(seconds: int) -> int`
  The UTC calendar year for epoch seconds.
  Example: `time.year(0) // 1970`
- `time.month(seconds: int) -> int`
  The UTC calendar month (1-12) for epoch seconds.
  Example: `time.month(0) // 1`
- `time.day(seconds: int) -> int`
  The UTC calendar day of month for epoch seconds.
  Example: `time.day(0) // 1`
- `time.hour(seconds: int) -> int`
  The UTC hour (0-23) for epoch seconds.
  Example: `time.hour(0) // 0`
- `time.minute(seconds: int) -> int`
  The UTC minute for epoch seconds.
  Example: `time.minute(0) // 0`
- `time.second(seconds: int) -> int`
  The UTC second for epoch seconds.
  Example: `time.second(0) // 0`
- `time.format(seconds: int, pattern: str) -> str`
  Formats epoch seconds with a strftime-style pattern, evaluated in UTC.
  Example: `time.format(0, "%Y-%m-%d") // "1970-01-01"`
- `time.in_timezone(seconds: int, zone: str) -> result<str,str>`
  An ISO-8601 string using `zone`'s own numeric UTC offset. `zone` is an IANA name like "America/New_York". Avoid relying on %Z/%z in a separate time.format call instead of this - those cannot reflect an arbitrary zone.
  Example: `time.in_timezone(0, "America/New_York") // Ok("1969-12-31T19:00:00-05:00")`
  Errors: Returns Err on failure; never panics.
- `time.format_in_timezone(seconds: int, pattern: str, zone: str) -> result<str,str>`
  Formats epoch seconds with a strftime-style pattern using `zone`'s zone- and DST-adjusted wall-clock time (year/month/day/hour/etc. are all zone-adjusted, unlike time.format's UTC-only fields).
  Example: `time.format_in_timezone(0, "%H:%M", "America/New_York") // Ok("19:00")`
  Errors: Returns Err on failure; never panics.

## duration

- `duration.seconds(n: int) -> int`
  `n` seconds as a plain epoch-second count, for arithmetic like time.now() + duration.minutes(5).
  Example: `duration.seconds(5) // 5`
- `duration.minutes(n: int) -> int`
  `n` minutes as a plain epoch-second count.
  Example: `duration.minutes(5) // 300`
- `duration.hours(n: int) -> int`
  `n` hours as a plain epoch-second count.
  Example: `duration.hours(2) // 7200`
- `duration.days(n: int) -> int`
  `n` days as a plain epoch-second count.
  Example: `duration.days(1) // 86400`

## Duration

- `Duration.of_seconds(n: int) -> Duration`
  Builds a Duration of `n` seconds. Duration is a distinct record type, not a plain int, so it can't be mistaken for an unrelated int at compile time the way the duration.* plain-int helpers can be.
  Example: `Duration.of_seconds(30) // a 30-second Duration`
- `Duration.of_minutes(n: int) -> Duration`
  Builds a Duration of `n` minutes.
  Example: `Duration.of_minutes(5) // a 5-minute Duration`
- `Duration.of_hours(n: int) -> Duration`
  Builds a Duration of `n` hours.
  Example: `Duration.of_hours(2) // a 2-hour Duration`
- `Duration.of_days(n: int) -> Duration`
  Builds a Duration of `n` days.
  Example: `Duration.of_days(1) // a 1-day Duration`
- `Duration.add(a: Duration, b: Duration) -> Duration`
  Sums two Durations.
  Example: `Duration.add(Duration.of_minutes(5), Duration.of_seconds(30)) // 5m30s`
- `Duration.sub(a: Duration, b: Duration) -> Duration`
  Subtracts one Duration from another.
  Example: `Duration.sub(Duration.of_minutes(5), Duration.of_seconds(30)) // 4m30s`
- `Duration.scale(duration: Duration, factor: int) -> Duration`
  Multiplies a Duration by an integer factor.
  Example: `Duration.scale(Duration.of_seconds(10), 3) // 30 seconds`
- `Duration.to_seconds(duration: Duration) -> int`
  A Duration's total length in seconds, for bridging back to plain epoch-second arithmetic. A Duration's own `seconds` field is also readable directly, since it's an ordinary record.
  Example: `Duration.to_seconds(Duration.of_minutes(2)) // 120`

## http

- `http.get(url: str) -> result<http,str>`
  Sends an HTTP GET request. Windows only. The response body is bounded at a fixed 10 MiB limit; exceeding it is an Err, not a truncated body - see http.request_with_limit for a caller-chosen limit that truncates instead.
  Example: `http.get("https://example.com") // Ok(response)`
  Errors: Returns Err on failure; never panics.
- `http.post(url: str, body: str, contentType: str) -> result<http,str>`
  Sends an HTTP POST request with a text body.
  Example: `http.post(url, "{}", "application/json") // Ok(response)`
  Errors: Returns Err on failure; never panics.
- `http.put(url: str, body: str, contentType: str) -> result<http,str>`
  Sends an HTTP PUT request with a text body.
  Example: `http.put(url, "{}", "application/json") // Ok(response)`
  Errors: Returns Err on failure; never panics.
- `http.delete(url: str) -> result<http,str>`
  Sends an HTTP DELETE request.
  Example: `http.delete(url) // Ok(response)`
  Errors: Returns Err on failure; never panics.
- `http.request(method: str, url: str, headers: Map<str,str>, body: str) -> result<http,str>`
  Sends an HTTP request with a custom method and headers, for anything http.get/post/put/delete don't cover.
  Example: `http.request("PATCH", url, headers, body) // Ok(response)`
  Errors: Returns Err on failure; never panics.
- `http.request_with_limit(method: str, url: str, headers: Map<str,str>, body: str, maxBytes: int) -> result<http,str>`
  Like http.request, but a response over `maxBytes` returns Ok with a truncated body instead of an error - the one http.* call that doesn't error on hitting its size limit. `maxBytes` <= 0 means unlimited; see http.truncated to detect whether truncation happened.
  Example: `http.request_with_limit("GET", url, headers, "", 1024) // Ok(response), possibly truncated`
  Errors: Returns Err on failure; never panics.
- `http.request_bytes(method: str, url: str, headers: Map<str,str>, data: bytes) -> result<http,str>`
  Like http.request, with a raw-bytes request body - for a body that isn't guaranteed valid text.
  Example: `http.request_bytes("POST", url, headers, data) // Ok(response)`
  Errors: Returns Err on failure; never panics.
- `http.status(response: http) -> int`
  An HTTP response's status code.
  Example: `http.status(response) // 200`
- `http.body(response: http) -> str`
  An HTTP response's body as text.
  Example: `http.body(response) // the response text`
- `http.content_type(response: http) -> str`
  An HTTP response's Content-Type header value.
  Example: `http.content_type(response) // "application/json"`
- `http.ok(response: http) -> bool`
  Whether the response status indicates success (2xx).
  Example: `http.ok(response) // true for a 2xx status`
- `http.body_bytes(response: http) -> bytes`
  An HTTP response's body as raw bytes, for a response that isn't guaranteed valid text.
  Example: `http.body_bytes(response) // the response body as bytes`
- `http.truncated(response: http) -> bool`
  Whether the response body was cut short at a byte limit. Always false for a response from any call other than http.request_with_limit.
  Example: `http.truncated(response) // false unless fetched via http.request_with_limit and cut short`

## list

- `list.len(list: [T]) -> int`
  Number of elements in a list.
  Example: `list.len([1, 2, 3]) // 3`
- `list.get(list: [T], index: int) -> T`
  The element at `index`. Bounds-check with list.len first when the index isn't already known-valid - there is no non-panicking variant.
  Example: `list.get([10, 20, 30], 1) // 20`
  Errors: E0316 if `index` is out of bounds.
- `list.push(list: [T], item: T) -> [T]`
  Returns a new list with `item` appended; `list` itself is unchanged, matching this language's immutable-by-default collection style.
  Example: `list.push([1, 2], 3) // [1, 2, 3]`
- `list.map(list: [T], callback: (T) -> U) -> [U]`
  Returns a new list with `callback` applied to every element. `callback` can be a named function reference (`&double`) or an immutable-capture closure.
  Example: `list.map([1, 2, 3], &double) // [2, 4, 6]`
- `list.filter(list: [T], callback: (T) -> bool) -> [T]`
  Returns a new list containing only the elements for which `callback` returns true, in their original order.
  Example: `list.filter([1, 2, 3, 4], &is_even) // [2, 4]`
- `list.find(list: [T], callback: (T) -> bool) -> Option<T>`
  The first element for which `callback` returns true, or None if none matches.
  Example: `list.find([1, 2, 3], &is_even) // Some(2)`
- `list.fold(list: [T], initial: U, callback: (U, T) -> U) -> U`
  Reduces a list to a single value by applying `callback(accumulator, item)` left to right, starting from `initial`. An empty list returns `initial` unchanged.
  Example: `list.fold([1, 2, 3], 0, &add) // 6`

## map

- `map.new() -> Map<any,any>`
  An empty map. Its key/value types are pinned by the first real map.set/map.get used with it in the same expression - passing a bare map.new() into something requiring a concrete Map<K,V> before that happens can fail to type-check; chain a real map.set first, or see map.remove for building a genuinely empty typed map.
  Example: `map.new() // an empty, not-yet-typed map`
- `map.len(map: Map<K,V>) -> int`
  Number of entries in a map.
  Example: `map.len(scores) // number of entries`
- `map.get(map: Map<K,V>, key: K) -> Option<V>`
  The value for `key`, or None if absent. Keys must be int, str, or bool (or a record/enum with an explicit `impl Eq`).
  Example: `map.get(scores, "Ada") // Some(92)`
- `map.has(map: Map<K,V>, key: K) -> bool`
  Whether `key` is present.
  Example: `map.has(scores, "Ada") // true`
- `map.set(map: Map<K,V>, key: K, value: V) -> Map<K,V>`
  Returns a new map with `key` bound to `value`, inserted or overwritten; `map` itself is unchanged.
  Example: `map.set(scores, "Ada", 92) // scores with Ada added or updated`
- `map.remove(map: Map<K,V>, key: K) -> Map<K,V>`
  Returns a new map with `key` removed; a no-op (returns an equivalent map) if `key` was already absent.
  Example: `map.remove(scores, "Ada") // scores without Ada`
- `map.keys(map: Map<K,V>) -> [K]`
  All keys, in unspecified order - don't rely on it matching insertion order.
  Example: `map.keys(scores) // ["Ada", "Grace"], order unspecified`
- `map.values(map: Map<K,V>) -> [V]`
  All values, in unspecified order, aligned with map.keys' own order for the same map.
  Example: `map.values(scores) // [92, 98], order unspecified`
- `map.map(map: Map<K,V>, callback: (V) -> U) -> Map<K,U>`
  Returns a new map with `callback` applied to every value; keys pass through unchanged. `callback` takes the value only, never a (key, value) pair.
  Example: `map.map(scores, &double) // every value doubled`
- `map.filter(map: Map<K,V>, callback: (V) -> bool) -> Map<K,V>`
  Returns a new map containing only the entries whose value `callback` returns true for.
  Example: `map.filter(scores, &is_passing) // only passing entries`
- `map.fold(map: Map<K,V>, initial: U, callback: (U, V) -> U) -> U`
  Reduces a map's values to a single value by applying `callback(accumulator, value)`, starting from `initial` - same callback convention as list.fold, over values only.
  Example: `map.fold(scores, 0, &sum) // total of all values`

## result

- `result.ok(value: T) -> result<T,str>`
  Wraps a value as a successful result, using this language's lowercase result<T,E> builtin convention (distinct from the capitalized Result enum - the two don't mix without result.to_result).
  Example: `result.ok(5) // Ok(5)`
- `result.err(message: str) -> result<any,str>`
  Wraps an error message as a failed result.
  Example: `result.err("not found") // Err("not found")`
- `result.is_ok(result: result<T,str>) -> bool`
  Whether a result is Ok.
  Example: `result.is_ok(result.ok(5)) // true`
- `result.value(result: result<T,str>) -> T`
  The success value. Check result.is_ok first (or handle both cases) rather than assuming Ok - there is no non-panicking variant.
  Example: `result.value(result.ok(5)) // 5`
  Errors: E0319 if the result is actually Err.
- `result.error(result: result<T,str>) -> str`
  The error message. Check result.is_ok first (or handle both cases) rather than assuming Err.
  Example: `result.error(result.err("bad")) // "bad"`
  Errors: E0320 if the result is actually Ok.
- `result.to_result(result: result<T,str>) -> result<T,str>`
  Normalizes any result-shaped value - whichever of the two conventions produced it - to the same runtime representation, so existing callers typed against one don't need to change.
  Example: `result.to_result(result.ok(5)) // Ok(5), same value either way`

## fixture

- `fixture.temp_dir() -> str`
  Creates and returns the path to a fresh, uniquely named temporary directory. No automatic cleanup - call fixture.cleanup when done.
  Example: `fixture.temp_dir() // e.g. "/tmp/lume_abc123"`
- `fixture.cleanup(path: str) -> bool`
  Recursively removes a directory, typically one created by fixture.temp_dir.
  Example: `fixture.cleanup(dir) // true`

## bytes

- `bytes.from_str(text: str) -> bytes`
  Converts text to bytes. bytes is represented identically to str at runtime (a deliberate scope reduction, not a NUL-safe binary type) - content with an embedded NUL byte truncates at the NUL on round-trip.
  Example: `bytes.from_str("hi") // the bytes for "hi"`
- `bytes.to_str(data: bytes) -> str`
  Converts bytes to text.
  Example: `bytes.to_str(data) // "hi"`
- `bytes.length(data: bytes) -> int`
  Number of bytes.
  Example: `bytes.length(data) // 2`

## expect

- `expect.equal(actual: T, expected: T) -> bool`
  Asserts two values are equal; fails the current test (not the whole run) if not. Only usable inside a native `test "name" { ... }` block.
  Example: `expect.equal(2 + 2, 4) // true`
- `expect.true(value: bool) -> bool`
  Asserts a value is true; fails the current test if not.
  Example: `expect.true(1 < 2) // true`
- `expect.ok(result: result<T,str>) -> bool`
  Asserts a result is Ok; fails the current test if not.
  Example: `expect.ok(result.ok(5)) // true`
- `expect.err(result: result<T,str>) -> bool`
  Asserts a result is Err; fails the current test if not.
  Example: `expect.err(result.err("bad")) // true`
- `expect.some(value: Option<T>) -> bool`
  Asserts an Option is Some; fails the current test if not.
  Example: `expect.some(Some(5)) // true`
- `expect.exit_code(result: process, code: int) -> bool`
  Asserts a process result's exit code equals `code`; fails the current test if not.
  Example: `expect.exit_code(result, 0) // true`
- `expect.stdout_contains(result: process, text: str) -> bool`
  Asserts a process result's captured stdout contains `text`; fails the current test if not.
  Example: `expect.stdout_contains(result, "ok") // true`
- `expect.stderr_contains(result: process, text: str) -> bool`
  Asserts a process result's captured stderr contains `text`; fails the current test if not.
  Example: `expect.stderr_contains(result, "error") // true`

