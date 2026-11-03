// A runnable proof of the C ABI embedding contract documented in
// docs/using-lume-the-fast-one.md section 22.1: a genuinely different
// host language (C, not a subprocess) loads lume.dll directly and
// calls a single named function inside a Lume program, round-trip,
// with no process-spawn per call. This is the C ABI counterpart of
// examples/embed_demo_host.py's subprocess proof - both exercise the
// same underlying contract (a function that decodes its own argument
// and encodes its own result), over two different transports.
//
// It also exercises the on-disk compiled-artifact cache lumeEmbedCall keeps
// between calls (section 22.1): hit/miss, invalidation, corruption, an
// unwritable cache directory, and the LUME_EMBED_CACHE=0 switch.
//
// lume.dll reads LUME_HOME and LUME_EMBED_CACHE from the process environment
// as it was when the DLL loaded - changing them afterwards (putenv or
// SetEnvironmentVariable) is not seen, confirmed live. So with no arguments
// this program is a driver: it sets up each scenario's environment, then
// re-launches itself with the scenario name so the DLL loads under it. Every
// scenario uses a scratch LUME_HOME, so running this never touches your real
// ~/.lume.
//
// Build (from the repo root, after .\build.ps1 has produced a Certo
// toolchain at the usual path):
//
//   certo build dist\lume.build.cto --emit-dll -o dist\lume.dll
//   clang examples\embed_demo_c_abi.c dist\lume.lib -o dist\embed_demo_c_abi.exe
//   .\dist\embed_demo_c_abi.exe
//
// Not wired into test.ps1, deliberately - same reason
// examples/embed_demo_host.py isn't: it needs a C toolchain (clang)
// on PATH, a separate step from the compiler's own normal
// build.ps1/test.ps1 cycle, run manually to prove the contract works
// across a real language boundary rather than only in-process.

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <windows.h>

// The actual exported symbol name, confirmed via
// `llvm-readobj --coff-exports dist\lume.dll`. certo-ffi --header now
// generates a matching declaration (it used to predict
// `certo_lumeEmbedCall`, fixed in rjreeves/Certo#7), but it is declared by
// hand here so this file stays a single self-contained example.
extern const char* certo_lume_embed_call(const char* source, const char* fnName, const char* rawArg, int64_t timeoutMs);

static int failures = 0;

static void check(const char* label, int condition) {
    printf("%s %s\n", condition ? "PASS" : "FAIL", label);
    if (!condition) failures++;
}

// The returned pointer is only guaranteed valid until the next call, so
// anything compared across calls is copied first.
static char* call(const char* source, const char* fn, const char* arg) {
    return _strdup(certo_lume_embed_call(source, fn, arg, 5000));
}

static double now_ms(void) {
    LARGE_INTEGER f, c;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart * 1000.0 / (double)f.QuadPart;
}

// ---- cache-directory helpers ----

static int count_lbc(const char* dir) {
    char pattern[MAX_PATH];
    snprintf(pattern, sizeof pattern, "%s\\*.lbc", dir);
    WIN32_FIND_DATAA data;
    HANDLE h = FindFirstFileA(pattern, &data);
    if (h == INVALID_HANDLE_VALUE) return 0;
    int n = 0;
    do { n++; } while (FindNextFileA(h, &data));
    FindClose(h);
    return n;
}

// Which artifact did a call just write? Snapshot the directory's file names
// before the call, and take the one name that wasn't there. (Not "the newest
// by timestamp": files written within the same instant are not reliably
// ordered, which made an earlier version of this check pick the wrong file.)
#define MAX_FILES 64
typedef struct { char names[MAX_FILES][MAX_PATH]; int n; } FileSet;

static void list_lbc(const char* dir, FileSet* set) {
    char pattern[MAX_PATH];
    snprintf(pattern, sizeof pattern, "%s\\*.lbc", dir);
    WIN32_FIND_DATAA data;
    set->n = 0;
    HANDLE h = FindFirstFileA(pattern, &data);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        if (set->n < MAX_FILES) snprintf(set->names[set->n++], MAX_PATH, "%s", data.cFileName);
    } while (FindNextFileA(h, &data));
    FindClose(h);
}

// Returns 1 and the full path if exactly one file in `dir` is absent from `before`.
static int find_new_lbc(const char* dir, const FileSet* before, char* out, size_t outSize) {
    FileSet now;
    list_lbc(dir, &now);
    int newCount = 0;
    for (int i = 0; i < now.n; i++) {
        int known = 0;
        for (int j = 0; j < before->n; j++) {
            if (strcmp(now.names[i], before->names[j]) == 0) { known = 1; break; }
        }
        if (!known) {
            newCount++;
            snprintf(out, outSize, "%s\\%s", dir, now.names[i]);
        }
    }
    return newCount == 1;
}

static long file_size(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fclose(f);
    return n;
}

static void rewrite_prefix(const char* path, long keep) {
    FILE* f = fopen(path, "rb");
    if (!f) return;
    char* buf = (char*)malloc((size_t)keep);
    size_t got = fread(buf, 1, (size_t)keep, f);
    fclose(f);
    f = fopen(path, "wb");
    fwrite(buf, 1, got, f);
    fclose(f);
    free(buf);
}

static void patch_byte(const char* path, long offset, char value, char* original) {
    FILE* f = fopen(path, "rb+");
    if (!f) return;
    fseek(f, offset, SEEK_SET);
    fread(original, 1, 1, f);
    fseek(f, offset, SEEK_SET);
    fwrite(&value, 1, 1, f);
    fclose(f);
}

static char byte_at(const char* path, long offset) {
    FILE* f = fopen(path, "rb");
    char c = 0;
    if (f) { fseek(f, offset, SEEK_SET); fread(&c, 1, 1, f); fclose(f); }
    return c;
}

// ---- Lume programs ----

// compileSource requires a complete program, including fn main, even
// though main() itself is never executed here - only the named
// function (square) is invoked via callPure. A real embedding-contract
// detail, discovered live while building this example.
static const char* VALID_SOURCE =
    "fn square(input: str) -> str {\n"
    "  let n = result.value(str.to_int(input))\n"
    "  return str.from_int(n * n)\n"
    "}\n"
    "fn main(args: [str]) -> int {\n"
    "  return 0\n"
    "}\n";

// Same program with different bodies, so each hashes to its own cache entry.
static const char* source_plus(int extra, char* buf, size_t size) {
    snprintf(buf, size,
        "fn square(input: str) -> str {\n"
        "  let n = result.value(str.to_int(input))\n"
        "  return str.from_int(n * n + %d)\n"
        "}\n"
        "fn main(args: [str]) -> int {\n"
        "  return 0\n"
        "}\n", extra);
    return buf;
}

// A larger program (50 extra functions, ~3.7 KB) so the miss-vs-hit timing
// difference is large enough to see.
static const char* large_source(char* buf, size_t size) {
    size_t used = (size_t)snprintf(buf, size,
        "fn square(input: str) -> str {\n"
        "  let n = result.value(str.to_int(input))\n"
        "  return str.from_int(n * n)\n"
        "}\n");
    for (int i = 0; i < 50 && used < size; i++) {
        used += (size_t)snprintf(buf + used, size - used,
            "fn filler%d(a: int, b: int) -> int {\n  let c = a + b\n  return c * %d\n}\n", i, i + 1);
    }
    snprintf(buf + used, size - used, "fn main(args: [str]) -> int {\n  return 0\n}\n");
    return buf;
}

static const char* OK_49 = "{\"ok\":true,\"value\":\"49\"}";

// ---- scenarios (each runs in its own process; see the header comment) ----

static void cache_dir_from_env(char* out, size_t size) {
    const char* home = getenv("LUME_HOME");
    snprintf(out, size, "%s\\.lume\\cache\\embed", home ? home : "");
}

static void scenario_main(void) {
    char dir[MAX_PATH];
    cache_dir_from_env(dir, sizeof dir);

    // ---- The embedding contract ----

    // Success path: C -> lume.dll -> compile + call square(7) -> 49.
    char* ok = call(VALID_SOURCE, "square", "7");
    check("success: returns the ok envelope with the squared value", strcmp(ok, OK_49) == 0);
    int afterFirst = count_lbc(dir);

    // Failure path: malformed source never reaches callPure at all.
    char* badSource = call("this is not valid lume", "square", "7");
    check("compile error: ok is false", strstr(badSource, "\"ok\":false") != NULL);
    check("compile error: error mentions a real E-code", strstr(badSource, "E02") != NULL);

    // Failure path: valid program, but the named function doesn't exist.
    char* missingFn = call(VALID_SOURCE, "doesNotExist", "7");
    check("missing function: ok is false", strstr(missingFn, "\"ok\":false") != NULL);
    check("missing function: error names the unknown callback", strstr(missingFn, "doesNotExist") != NULL);

    // Failure path: valid program and function, bad input causes a
    // genuine Lume-level runtime panic (result.value on an Err).
    char* panicked = call(VALID_SOURCE, "square", "not-a-number");
    check("runtime panic: ok is false", strstr(panicked, "\"ok\":false") != NULL);

    // ---- The artifact cache ----

    check("cache: the first successful compile wrote exactly one artifact", afterFirst == 1);
    check("cache: failed compiles and error calls wrote no further artifact", count_lbc(dir) == 1);

    // Errors are identical on a cache hit.
    char* badAgain = call("this is not valid lume", "square", "7");
    check("cache: a compile error is the same on repeat", strcmp(badSource, badAgain) == 0);
    char* missingAgain = call(VALID_SOURCE, "doesNotExist", "7");
    check("cache: a missing-function error is the same on a cache hit", strcmp(missingFn, missingAgain) == 0);
    char* panicAgain = call(VALID_SOURCE, "square", "not-a-number");
    check("cache: a runtime-panic error is the same on a cache hit", strcmp(panicked, panicAgain) == 0);
    char* okAgain = call(VALID_SOURCE, "square", "7");
    check("cache: a hit returns the same result as the miss", strcmp(ok, okAgain) == 0);
    check("cache: a hit does not write another artifact", count_lbc(dir) == 1);

    // Miss vs hit on a larger program (informational timing, not asserted).
    char large[8192];
    large_source(large, sizeof large);
    double t0 = now_ms();
    char* missResult = call(large, "square", "7");
    double t1 = now_ms();
    char* hitResult = call(large, "square", "7");
    check("cache: a larger program gives the same result on miss and hit", strcmp(missResult, hitResult) == 0 && strcmp(missResult, OK_49) == 0);
    // Average over many hits: a single hit right after the artifact was
    // written can be slowed by the OS (file-system caching, antivirus), which
    // is not what a host calling repeatedly would see.
    const int hits = 50;
    double t2 = now_ms();
    for (int i = 0; i < hits; i++) free(call(large, "square", "7"));
    double t3 = now_ms();
    printf("     (%zu-byte program: first call (miss) %.3f ms; average hit over %d calls %.3f ms)\n",
           strlen(large), t1 - t0, hits, (t3 - t2) / hits);

    // A different source is a different entry, never a stale hit.
    char changedSource[512];
    source_plus(1, changedSource, sizeof changedSource);
    int before = count_lbc(dir);
    char* changed = call(changedSource, "square", "7");
    check("cache: a changed source gives its own result, not the old one", strcmp(changed, "{\"ok\":true,\"value\":\"50\"}") == 0);
    check("cache: the changed source got its own artifact", count_lbc(dir) == before + 1);

    // Corruption and staleness are misses that repair themselves.
    char corruptSource[512], file[MAX_PATH];
    source_plus(2, corruptSource, sizeof corruptSource);
    FileSet snapshot;
    list_lbc(dir, &snapshot);
    call(corruptSource, "square", "7");
    int found = find_new_lbc(dir, &snapshot, file, sizeof file);
    check("cache: corruption test has an artifact to corrupt", found);
    if (found) {
        long original = file_size(file);
        rewrite_prefix(file, 100);
        char* afterCorrupt = call(corruptSource, "square", "7");
        check("cache: a truncated artifact is ignored, not an error", strcmp(afterCorrupt, "{\"ok\":true,\"value\":\"51\"}") == 0);
        check("cache: ...and is rewritten with a complete one", file_size(file) == original);
        free(afterCorrupt);
    }

    char staleSource[512];
    source_plus(3, staleSource, sizeof staleSource);
    list_lbc(dir, &snapshot);
    call(staleSource, "square", "7");
    found = find_new_lbc(dir, &snapshot, file, sizeof file);
    check("cache: staleness test has an artifact to age", found);
    if (found) {
        char original = 0;
        // Bytes 68..131 hold the compiler build hash; changing one makes
        // the artifact look like it came from a different compiler build.
        patch_byte(file, 70, 'Z', &original);
        char* afterStale = call(staleSource, "square", "7");
        check("cache: an other-build artifact is ignored, not an error", strcmp(afterStale, "{\"ok\":true,\"value\":\"52\"}") == 0);
        check("cache: ...and is rewritten with this build's hash", byte_at(file, 70) == original);
        free(afterStale);
    }
}

// LUME_HOME points somewhere a directory cannot be created (under a regular
// file): the cache must never turn that into a failed call.
static void scenario_unwritable(void) {
    char* result = call(VALID_SOURCE, "square", "7");
    check("cache: an unwritable cache directory still returns the right result", strcmp(result, OK_49) == 0);
    char* again = call(VALID_SOURCE, "square", "7");
    check("cache: ...and keeps doing so on every call", strcmp(again, OK_49) == 0);
}

// LUME_EMBED_CACHE=0: right result, nothing written.
static void scenario_off(void) {
    char dir[MAX_PATH];
    cache_dir_from_env(dir, sizeof dir);
    char* result = call(VALID_SOURCE, "square", "7");
    check("cache off: still returns the right result", strcmp(result, OK_49) == 0);
    check("cache off: writes no artifact", count_lbc(dir) == 0);
}

// ---- driver ----

static int run_scenario(const char* self, const char* name) {
    char commandLine[MAX_PATH + 64];
    snprintf(commandLine, sizeof commandLine, "\"%s\" %s", self, name);
    STARTUPINFOA startup;
    PROCESS_INFORMATION process;
    ZeroMemory(&startup, sizeof startup);
    startup.cb = sizeof startup;
    if (!CreateProcessA(NULL, commandLine, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &process)) {
        printf("FAIL could not launch scenario %s\n", name);
        return 1;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(process.hProcess, &code);
    CloseHandle(process.hProcess);
    CloseHandle(process.hThread);
    return (int)code;
}

static int driver(void) {
    char self[MAX_PATH], temp[MAX_PATH], base[MAX_PATH], home[MAX_PATH], blocker[MAX_PATH];
    GetModuleFileNameA(NULL, self, sizeof self);
    GetTempPathA(sizeof temp, temp);
    snprintf(base, sizeof base, "%slume_embed_c_abi_%lu", temp, (unsigned long)GetCurrentProcessId());
    CreateDirectoryA(base, NULL);

    int total = 0;

    snprintf(home, sizeof home, "%s\\main", base);
    SetEnvironmentVariableA("LUME_HOME", home);
    SetEnvironmentVariableA("LUME_EMBED_CACHE", "1");
    total += run_scenario(self, "main");

    // A regular file sits where the cache directory would have to be created.
    snprintf(blocker, sizeof blocker, "%s\\blocker", base);
    FILE* f = fopen(blocker, "wb");
    if (f) { fputs("x", f); fclose(f); }
    snprintf(home, sizeof home, "%s\\under", blocker);
    SetEnvironmentVariableA("LUME_HOME", home);
    total += run_scenario(self, "unwritable");

    snprintf(home, sizeof home, "%s\\off", base);
    SetEnvironmentVariableA("LUME_HOME", home);
    SetEnvironmentVariableA("LUME_EMBED_CACHE", "0");
    total += run_scenario(self, "off");

    char cleanup[MAX_PATH + 32];
    snprintf(cleanup, sizeof cleanup, "rmdir /s /q \"%s\"", base);
    system(cleanup);

    printf("\n");
    if (total) {
        printf("%d check(s) failed\n", total);
        return 1;
    }
    printf("all C ABI embedding-contract checks passed\n");
    return 0;
}

int main(int argc, char** argv) {
    if (argc < 2) return driver();
    if (strcmp(argv[1], "main") == 0) scenario_main();
    else if (strcmp(argv[1], "unwritable") == 0) scenario_unwritable();
    else if (strcmp(argv[1], "off") == 0) scenario_off();
    else { printf("unknown scenario %s\n", argv[1]); return 1; }
    return failures;
}
