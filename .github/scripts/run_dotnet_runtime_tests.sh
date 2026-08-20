#!/usr/bin/env bash
set -euo pipefail

godot_bin="${GODOT_DOTNET_BIN:-godot}"
test_root="$(mktemp -d)"
cleanup() {
	rm -rf "$test_root"
}
trap cleanup EXIT

run_godot_checked() {
	local output
	local status
	set +e
	output="$(python3 - "$@" <<'PY'
import os
import subprocess
import sys

timeout_seconds = int(os.environ.get("GODOT_TEST_TIMEOUT_SECONDS", "120"))
try:
    completed = subprocess.run(
        sys.argv[1:],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=timeout_seconds,
    )
except subprocess.TimeoutExpired as error:
    output = error.stdout or ""
    if isinstance(output, bytes):
        output = output.decode(errors="replace")
    sys.stdout.write(output)
    print(
        f"Godot test exceeded the {timeout_seconds}-second timeout.",
        file=sys.stderr,
    )
    raise SystemExit(124)

sys.stdout.write(completed.stdout)
raise SystemExit(completed.returncode)
PY
)"
	status=$?
	set -e
	printf '%s\n' "$output"
	if [ "$status" -ne 0 ]; then
		return "$status"
	fi
	if printf '%s\n' "$output" |
		grep -Eq '^[[:space:]]*(SCRIPT ERROR|ERROR|FATAL|Parse Error):'
	then
		printf '%s\n' "Godot reported a script or runtime error." >&2
		return 1
	fi
}

tar \
	--exclude='./.git' \
	--exclude='./.godot' \
	--exclude='./docs/node_modules' \
	-cf - . |
	tar -xf - -C "$test_root"

# Runtime tests do not need editor plugins; disabling them avoids editor-only startup work.
perl -0pi -e \
	's/enabled=PackedStringArray\([^\n]*\)/enabled=PackedStringArray()/' \
	"$test_root/project.godot"

printf '%s\n' \
	'<Project Sdk="Godot.NET.Sdk/4.7.1">' \
	'  <PropertyGroup>' \
	'    <TargetFramework>net8.0</TargetFramework>' \
	'    <EnableDynamicLoading>true</EnableDynamicLoading>' \
	'    <Nullable>enable</Nullable>' \
	'    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>' \
	'  </PropertyGroup>' \
	'</Project>' \
	> "$test_root/Konado Project.csproj"

(
	cd "$test_root"
	dotnet build "Konado Project.csproj" --configuration Debug --nologo
)
"$godot_bin" --headless --editor --path "$test_root" --quit >/dev/null 2>&1
run_godot_checked "$godot_bin" \
	--headless \
	--path "$test_root" \
	"$test_root/tests/dotnet/konado_runtime_tests.tscn"
