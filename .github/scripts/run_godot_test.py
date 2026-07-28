#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
import sys


ERROR_PATTERN = re.compile(r"(?m)^[ \t]*(?:SCRIPT ERROR|ERROR|FATAL|Parse Error):")


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
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    command = [
        args.godot,
        "--headless",
        "--path",
        ".",
        "--script",
        args.test_path,
    ]
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
    if ERROR_PATTERN.search(result.stdout):
        print("Godot emitted a script/runtime error despite returning exit code 0.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
