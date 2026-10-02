// A runnable proof of the C ABI embedding contract documented in
// docs/using-lume-the-fast-one.md section 23: a genuinely different
// host language (C, not a subprocess) loads lume.dll directly and
// calls a single named function inside a Lume program, round-trip,
// with no process-spawn per call. This is the C ABI counterpart of
// examples/embed_demo_host.py's subprocess proof - both exercise the
// same underlying contract (a function that decodes its own argument
// and encodes its own result), over two different transports.
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

#include <stdio.h>
#include <string.h>
#include <stdint.h>

// The actual exported symbol name, confirmed via
// `llvm-readobj --coff-exports dist\lume.dll` - certo-ffi --header
// predicts `certo_lumeEmbedCall` (no case conversion applied to a
// multi-word pub fn name), but the real codegen snake_cases it:
// `certo_lume_embed_call`. A real discrepancy in certo-ffi's header
// generator, found live while building this example, not assumed -
// declared by hand here rather than trusting the generated header.
extern const char* certo_lume_embed_call(const char* source, const char* fnName, const char* rawArg, int64_t timeoutMs);

static int failures = 0;

static void check(const char* label, int condition) {
    printf("%s %s\n", condition ? "PASS" : "FAIL", label);
    if (!condition) failures++;
}

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

int main(void) {
    // Success path: C -> lume.dll -> compile + call square(7) -> 49.
    const char* ok = certo_lume_embed_call(VALID_SOURCE, "square", "7", 5000);
    check("success: returns the ok envelope with the squared value",
          strcmp(ok, "{\"ok\":true,\"value\":\"49\"}") == 0);

    // Failure path: malformed source never reaches callPure at all.
    const char* badSource = certo_lume_embed_call("this is not valid lume", "square", "7", 5000);
    check("compile error: ok is false", strstr(badSource, "\"ok\":false") != NULL);
    check("compile error: error mentions a real E-code", strstr(badSource, "E02") != NULL);

    // Failure path: valid program, but the named function doesn't exist.
    const char* missingFn = certo_lume_embed_call(VALID_SOURCE, "doesNotExist", "7", 5000);
    check("missing function: ok is false", strstr(missingFn, "\"ok\":false") != NULL);
    check("missing function: error names the unknown callback", strstr(missingFn, "doesNotExist") != NULL);

    // Failure path: valid program and function, bad input causes a
    // genuine Lume-level runtime panic (result.value on an Err).
    const char* panicked = certo_lume_embed_call(VALID_SOURCE, "square", "not-a-number", 5000);
    check("runtime panic: ok is false", strstr(panicked, "\"ok\":false") != NULL);

    printf("\n");
    if (failures) {
        printf("%d check(s) failed\n", failures);
        return 1;
    }
    printf("all C ABI embedding-contract checks passed\n");
    return 0;
}
