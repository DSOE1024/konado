#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
import sys


ERROR_PATTERN = re.compile(r"(?m)^[ \t]*(?:SCRIPT ERROR|ERROR|FATAL|Parse Error):")
EDITOR_SHUTDOWN_ERROR_PATTERN = re.compile(
    r"(?m)^ERROR: (?:\d+ resources still in use at exit|"
    r"\d+ RID allocations of type '.+' were leaked at exit)"
    r"(?: \(run with --verbose for details\))?\.\n"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a headless Godot test and reject script errors hidden by exit code 0."
    )
    parser.add_argument("test_path", help="Godot script path to execute")
    parser.add_argument(
        "--godot",
        default=os.environ.get("GODOT_BIN", "godot"),
        help="Godot executable (default: GODOT_BIN or godot)",
    )
    parser.add_argument(
        "--editor",
        action="store_true",
        help="Initialize the editor and enabled plugins before running the test.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    command = [
        args.godot,
        "--headless",
    ]
    if args.editor:
        command.append("--editor")
    command.extend(["--path", ".", "--script", args.test_path])
    result = subprocess.run(
        command,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    sys.stdout.write(result.stdout)
    if result.returncode != 0:
        return result.returncode
    checked_output = result.stdout
    if args.editor:
        checked_output = EDITOR_SHUTDOWN_ERROR_PATTERN.sub("", checked_output)
    if ERROR_PATTERN.search(checked_output):
        print("Godot emitted a script/runtime error despite returning exit code 0.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
