#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"
binary="$repository_root/_artifact/gomlgo-build/bin/cmd/gomlgo/gomlgo"
output="$repository_root/_artifact/smoke"
mkdir -p "$output"

"$binary" scan testdata/execute/pure/basic_values/main.go > "$output/scan.json"
"$binary" parse testdata/execute/pure/basic_values/main.go > "$output/parse.json"
"$binary" check testdata/execute/pure/basic_values/main.go > "$output/check.json"

for fixture in pure/basic_values pure/native_calls native_callback; do
    source_file="testdata/execute/$fixture/main.go"
    label="${fixture//\//-}"
    bash toolchain/go.sh run "$source_file" > "$output/$label.expected" 2> "$output/$label.expected.stderr"
    "$binary" run "$source_file" > "$output/$label.actual" 2> "$output/$label.actual.stderr"
    diff -u "$output/$label.expected" "$output/$label.actual"
    diff -u "$output/$label.expected.stderr" "$output/$label.actual.stderr"
done

"$binary" run testdata/execute/pure/generated_task_scope/main.goml.go > "$output/generated-task-scope.actual"
diff -u testdata/execute/pure/generated_task_scope/main.goml.out "$output/generated-task-scope.actual"
