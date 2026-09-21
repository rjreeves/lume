# A runnable proof of the subprocess-embedding contract documented in
# docs/using-lume-the-fast-one.md section 22: a genuinely different
# host language (Python, not Lume or PowerShell) spawns dist/lume.exe,
# passes typed JSON in via a CLI argument, and reads typed JSON back
# from stdout - with stderr and the exit code checked on every failure
# path too, not just the success path.
#
# Run from the repo root: python3 examples/embed_demo_host.py

import json
import os
import subprocess
import sys

# Windows CreateProcess (what subprocess.run shells out to) does not
# resolve a relative forward-slash path the way a shell would - it needs
# an absolute path here, confirmed live (a bare "dist/lume.exe" raised
# FileNotFoundError even though the file exists at that path from cwd).
LUME = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "dist/lume.exe")
SCRIPT = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else "examples/embed_demo.lume")

failures = []


def check(label, condition):
    status = "PASS" if condition else "FAIL"
    print(f"{status} {label}")
    if not condition:
        failures.append(label)


def run(arg=None):
    args = [LUME, "run", SCRIPT]
    if arg is not None:
        args.append(arg)
    return subprocess.run(args, capture_output=True, text=True)


# Success path: Python -> subprocess -> Lume -> structured stdout back to Python.
result = run(json.dumps({"n": 5}))
check("success: exit code is 0", result.returncode == 0)
check("success: stderr is empty", result.stderr == "")
try:
    payload = json.loads(result.stdout)
    check("success: stdout is valid JSON", True)
    check("success: payload matches expected shape", payload == {"input": 5, "squared": 25})
except (json.JSONDecodeError, ValueError):
    check("success: stdout is valid JSON", False)

# Failure path: malformed JSON input.
result = run("not json")
check("invalid json: exit code is 1", result.returncode == 1)
check("invalid json: stdout is empty", result.stdout == "")
check("invalid json: stderr is non-empty", len(result.stderr.strip()) > 0)

# Failure path: well-formed JSON, semantically invalid (negative n).
result = run(json.dumps({"n": -3}))
check("negative n: exit code is 1", result.returncode == 1)
check("negative n: stdout is empty", result.stdout == "")
check("negative n: stderr mentions the value", "-3" in result.stderr)

# Failure path: missing argument entirely.
result = run(None)
check("missing arg: exit code is 1", result.returncode == 1)
check("missing arg: stdout is empty", result.stdout == "")

print()
if failures:
    print(f"{len(failures)} check(s) failed: {failures}")
    sys.exit(1)
else:
    print("all embedding-contract checks passed")
    sys.exit(0)
