# Lume Builtin Reference

Generated from `builtinDocs()` in `src/lume.cto` (the same source `lume api` reads) by `lume api-docs` - do not hand-edit; regenerated on every build. For usage and semantics, see `docs/using-lume-the-fast-one.md`.

## args

- `args.count() -> int` - Number of command-line arguments, excluding the program name.
- `args.get(index: int) -> str` - The argument at `index`; panics if out of bounds.

## fs

- `fs.exists(path: str) -> bool` - Whether a file or directory exists at `path`.
- `fs.read_text(path: str) -> str` - Reads a file's full contents as text; fails at runtime (E0312) if it can't be read.
- `fs.write_text(path: str, content: str) -> bool` - Writes `content` to `path`, creating or overwriting it.
- `fs.try_read_text(path: str) -> result<str,str>` - Reads a file's full contents as text, returning Err instead of failing on a read error.
- `fs.try_write_text(path: str, content: str) -> result<bool,str>` - Writes `content` to `path`, returning Err instead of failing on a write error.
- `fs.read_bytes(path: str) -> result<bytes,str>` - Reads a file's full contents as raw bytes.
- `fs.write_bytes(path: str, data: bytes) -> bool` - Writes raw bytes to `path`, creating or overwriting it.

## env

- `env.get(name: str) -> str` - The environment variable's value, or "" if it isn't set.
- `env.has(name: str) -> bool` - Whether an environment variable is set.
- `env.set(name: str, value: str) -> bool` - Sets an environment variable for the current process.
- `env.unset(name: str) -> bool` - Removes an environment variable from the current process.

## process

- `process.run(executable: str, arguments: [str]) -> process` - Runs a process to completion and captures its exit code, stdout, and stderr.
- `process.run_with_input(executable: str, arguments: [str], input: str) -> process` - Like process.run, piping `input` to the child process's stdin.
- `process.run_with_env(executable: str, arguments: [str], env: Map<str,str>) -> process` - Like process.run, with `env` overriding environment variables for the child process only.
- `process.run_with_options(executable: str, arguments: [str], workingDir: str, timeoutMs: int) -> process` - Like process.run, with a working directory ("" for unchanged) and an optional timeout in milliseconds (<= 0 for none); a timed-out process is killed and reports exit code -1.
- `process.code(result: process) -> int` - The child process's exit code.
- `process.stdout(result: process) -> str` - The child process's captured standard output.
- `process.stderr(result: process) -> str` - The child process's captured standard error.
- `process.ok(result: process) -> bool` - Whether the process exited with code 0.

## str

- `str.len(value: str) -> int` - Number of bytes in a string.
- `str.trim(value: str) -> str` - Removes leading and trailing whitespace.
- `str.upper(value: str) -> str` - Converts to uppercase.
- `str.lower(value: str) -> str` - Converts to lowercase.
- `str.from_int(value: int) -> str` - Formats an int as decimal text.
- `str.to_int(value: str) -> result<int,str>` - Parses decimal text as an int; Err if it isn't a valid integer.
- `str.contains(haystack: str, needle: str) -> bool` - Whether `haystack` contains `needle`.
- `str.starts_with(value: str, prefix: str) -> bool` - Whether `value` starts with `prefix`.
- `str.ends_with(value: str, suffix: str) -> bool` - Whether `value` ends with `suffix`.

## json

- `json.valid(text: str) -> bool` - Whether `text` parses as valid JSON.
- `json.get(text: str, key: str) -> str` - A top-level key's value from a JSON object, as text (requires `text` to decode as a JSON object).
- `json.encode(value: T) -> result<str,str>` - Encodes a value (int/str/bool/list/record, recursively, plus enums including Option/Result) as a JSON string.

## path

- `path.join(a: str, b: str) -> str` - Joins two path segments.
- `path.basename(path: str) -> str` - The final path component.
- `path.dirname(path: str) -> str` - The path with its final component removed.
- `path.extension(path: str) -> Option<str>` - The file extension, without the dot, or None.
- `path.stem(path: str) -> str` - The final path component without its extension.

## dir

- `dir.list(path: str) -> result<[str],str>` - Lists a directory's immediate entries (names only, unsorted).
- `dir.walk(path: str, maxDepth: int) -> result<[str],str>` - Recursively lists files under `path` as full paths (not directories); `maxDepth` 0 means only `path`'s own files; an unreadable subdirectory is skipped, not a failure.

## time

- `time.now() -> int` - Current Unix epoch time in seconds.
- `time.to_iso(seconds: int) -> str` - Formats epoch seconds as a UTC ISO-8601 string.
- `time.year(seconds: int) -> int` - The UTC calendar year for epoch seconds.
- `time.month(seconds: int) -> int` - The UTC calendar month (1-12) for epoch seconds.
- `time.day(seconds: int) -> int` - The UTC calendar day of month for epoch seconds.
- `time.hour(seconds: int) -> int` - The UTC hour (0-23) for epoch seconds.
- `time.minute(seconds: int) -> int` - The UTC minute for epoch seconds.
- `time.second(seconds: int) -> int` - The UTC second for epoch seconds.
- `time.format(seconds: int, pattern: str) -> str` - Formats epoch seconds with a strftime-style pattern, evaluated in UTC.
- `time.in_timezone(seconds: int, zone: str) -> result<str,str>` - An ISO-8601 string using `zone`'s own numeric UTC offset (an IANA zone name; Err if unrecognized).
- `time.format_in_timezone(seconds: int, pattern: str, zone: str) -> result<str,str>` - Formats epoch seconds with a strftime-style pattern using `zone`'s zone- and DST-adjusted wall-clock time.

## duration

- `duration.seconds(n: int) -> int` - `n` seconds as a plain epoch-second count.
- `duration.minutes(n: int) -> int` - `n` minutes as a plain epoch-second count.
- `duration.hours(n: int) -> int` - `n` hours as a plain epoch-second count.
- `duration.days(n: int) -> int` - `n` days as a plain epoch-second count.

## Duration

- `Duration.of_seconds(n: int) -> Duration` - Builds a Duration of `n` seconds.
- `Duration.of_minutes(n: int) -> Duration` - Builds a Duration of `n` minutes.
- `Duration.of_hours(n: int) -> Duration` - Builds a Duration of `n` hours.
- `Duration.of_days(n: int) -> Duration` - Builds a Duration of `n` days.
- `Duration.add(a: Duration, b: Duration) -> Duration` - Sums two Durations.
- `Duration.sub(a: Duration, b: Duration) -> Duration` - Subtracts one Duration from another.
- `Duration.scale(duration: Duration, factor: int) -> Duration` - Multiplies a Duration by an integer factor.
- `Duration.to_seconds(duration: Duration) -> int` - A Duration's total length in seconds, for plain epoch-second arithmetic.

## http

- `http.get(url: str) -> result<http,str>` - Sends an HTTP GET request.
- `http.post(url: str, body: str, contentType: str) -> result<http,str>` - Sends an HTTP POST request with a text body.
- `http.put(url: str, body: str, contentType: str) -> result<http,str>` - Sends an HTTP PUT request with a text body.
- `http.delete(url: str) -> result<http,str>` - Sends an HTTP DELETE request.
- `http.request(method: str, url: str, headers: Map<str,str>, body: str) -> result<http,str>` - Sends an HTTP request with a custom method and headers.
- `http.request_with_limit(method: str, url: str, headers: Map<str,str>, body: str, maxBytes: int) -> result<http,str>` - Like http.request, but a response over `maxBytes` returns Ok with a truncated body instead of an error (`maxBytes` <= 0 means unlimited; see http.truncated).
- `http.request_bytes(method: str, url: str, headers: Map<str,str>, data: bytes) -> result<http,str>` - Like http.request, with a raw-bytes request body.
- `http.status(response: http) -> int` - An HTTP response's status code.
- `http.body(response: http) -> str` - An HTTP response's body as text.
- `http.content_type(response: http) -> str` - An HTTP response's Content-Type header value.
- `http.ok(response: http) -> bool` - Whether the response status indicates success (2xx).
- `http.body_bytes(response: http) -> bytes` - An HTTP response's body as raw bytes.
- `http.truncated(response: http) -> bool` - Whether the response body was cut short at a byte limit (always false outside http.request_with_limit).

## list

- `list.len(list: [T]) -> int` - Number of elements in a list.
- `list.get(list: [T], index: int) -> T` - The element at `index`; panics if out of bounds.
- `list.push(list: [T], item: T) -> [T]` - Returns a new list with `item` appended.
- `list.map(list: [T], callback: (T) -> U) -> [U]` - Returns a new list with `callback` applied to every element.
- `list.filter(list: [T], callback: (T) -> bool) -> [T]` - Returns a new list containing only the elements for which `callback` returns true.
- `list.find(list: [T], callback: (T) -> bool) -> Option<T>` - The first element for which `callback` returns true, or None.
- `list.fold(list: [T], initial: U, callback: (U, T) -> U) -> U` - Reduces a list to a single value by applying `callback` left to right, starting from `initial`.

## map

- `map.new() -> Map<any,any>` - An empty map; its key/value types are pinned by the first real map.set/map.get used with it.
- `map.len(map: Map<K,V>) -> int` - Number of entries in a map.
- `map.get(map: Map<K,V>, key: K) -> Option<V>` - The value for `key`, or None if absent.
- `map.has(map: Map<K,V>, key: K) -> bool` - Whether `key` is present.
- `map.set(map: Map<K,V>, key: K, value: V) -> Map<K,V>` - Returns a new map with `key` bound to `value`.
- `map.remove(map: Map<K,V>, key: K) -> Map<K,V>` - Returns a new map with `key` removed.
- `map.keys(map: Map<K,V>) -> [K]` - All keys, in unspecified order.
- `map.values(map: Map<K,V>) -> [V]` - All values, in unspecified order.
- `map.map(map: Map<K,V>, callback: (V) -> U) -> Map<K,U>` - Returns a new map with `callback` applied to every value; keys pass through unchanged.
- `map.filter(map: Map<K,V>, callback: (V) -> bool) -> Map<K,V>` - Returns a new map containing only the entries whose value `callback` returns true for.
- `map.fold(map: Map<K,V>, initial: U, callback: (U, V) -> U) -> U` - Reduces a map's values to a single value by applying `callback`, starting from `initial`.

## result

- `result.ok(value: T) -> result<T,str>` - Wraps a value as a successful result.
- `result.err(message: str) -> result<any,str>` - Wraps an error message as a failed result.
- `result.is_ok(result: result<T,str>) -> bool` - Whether a result is Ok.
- `result.value(result: result<T,str>) -> T` - The success value; panics if the result is Err.
- `result.error(result: result<T,str>) -> str` - The error message; panics if the result is Ok.
- `result.to_result(result: result<T,str>) -> result<T,str>` - Normalizes any result-shaped value (lowercase result or the Result enum) to the same runtime representation.

## fixture

- `fixture.temp_dir() -> str` - Creates and returns the path to a fresh, uniquely named temporary directory.
- `fixture.cleanup(path: str) -> bool` - Recursively removes a directory (typically one created by fixture.temp_dir).

## bytes

- `bytes.from_str(text: str) -> bytes` - Converts text to bytes.
- `bytes.to_str(data: bytes) -> str` - Converts bytes to text.
- `bytes.length(data: bytes) -> int` - Number of bytes.

## expect

- `expect.equal(actual: T, expected: T) -> bool` - Asserts two values are equal; fails the current test if not.
- `expect.true(value: bool) -> bool` - Asserts a value is true; fails the current test if not.
- `expect.ok(result: result<T,str>) -> bool` - Asserts a result is Ok; fails the current test if not.
- `expect.err(result: result<T,str>) -> bool` - Asserts a result is Err; fails the current test if not.
- `expect.some(value: Option<T>) -> bool` - Asserts an Option is Some; fails the current test if not.
- `expect.exit_code(result: process, code: int) -> bool` - Asserts a process result's exit code equals `code`; fails the current test if not.
- `expect.stdout_contains(result: process, text: str) -> bool` - Asserts a process result's captured stdout contains `text`; fails the current test if not.
- `expect.stderr_contains(result: process, text: str) -> bool` - Asserts a process result's captured stderr contains `text`; fails the current test if not.

