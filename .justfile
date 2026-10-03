set shell := ["bash", "-euo", "pipefail", "-c"]

goml := env("GOML", justfile_directory() + "/_artifact/toolchain/bin/goml")
build_jobs := env("GOML_BUILD_JOBS", "2")
test_jobs := env("GOML_TEST_JOBS", "2")

default: build

toolchain:
    bash toolchain/install.sh

fmt:
    "{{goml}}" fmt

fmt-check:
    "{{goml}}" fmt --check

native-test:
    bash toolchain/go.sh test -race ./...

oracle:
    mkdir -p _artifact/gomlgo
    cd oracle && bash ../toolchain/go.sh test ./...
    cd oracle && bash ../toolchain/go.sh build -o ../_artifact/gomlgo/oracle .

test: oracle
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" "{{goml}}" test --target-dir _artifact/gomlgo-test --jobs "{{test_jobs}}" --timeout 10m

type-test: test

build: oracle
    "{{goml}}" build --target-dir _artifact/gomlgo-build --jobs "{{build_jobs}}"

diff: build
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_scan_diff/gomlgo_scan_diff testdata
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff ast-comments testdata/valid
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff parse-acceptance testdata/invalid
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff parse-acceptance testdata/regressions

type-diff: build
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_type_diff/gomlgo_type_diff testdata/typecheck

type-diff-official: build
    systemd-run --user --scope -p MemoryHigh=8G -p MemoryMax=10G -p MemorySwapMax=2G -p TasksMax=256 -p CPUQuota=300% bash -euo pipefail -c 'gomlgo_src=$(bash toolchain/go.sh --source-root) && find "$gomlgo_src/internal/types/testdata/check" "$gomlgo_src/internal/types/testdata/spec" "$gomlgo_src/internal/types/testdata/examples" "$gomlgo_src/internal/types/testdata/fixedbugs" "$gomlgo_src/go/types/testdata/local" -type f -name "*.go" -print0 | sort -z | xargs -0 -r -n1 env GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_type_diff/gomlgo_type_diff info'

type-diagnostics-official: build
    systemd-run --user --scope -p MemoryHigh=8G -p MemoryMax=10G -p MemorySwapMax=2G -p TasksMax=256 -p CPUQuota=300% bash -euo pipefail -c 'gomlgo_src=$(bash toolchain/go.sh --source-root) && find "$gomlgo_src/internal/types/testdata/check" "$gomlgo_src/internal/types/testdata/spec" "$gomlgo_src/internal/types/testdata/examples" "$gomlgo_src/internal/types/testdata/fixedbugs" "$gomlgo_src/go/types/testdata/local" -type f -name "*.go" -print0 | sort -z | xargs -0 -r -n1 env GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_type_diff/gomlgo_type_diff diagnostics'

type-diff-goroot limit="-1" scope="std" mode="acceptance" goos="linux" goarch="amd64" cgo="0" tests="none": build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && systemd-run --user --scope -p MemoryHigh=6G -p MemoryMax=8G -p MemorySwapMax=1G -p TasksMax=512 -p CPUQuota=300% env GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_type_goroot_diff/gomlgo_type_goroot_diff "{{mode}}" "{{scope}}" "{{limit}}" "$gomlgo_src" "" "{{goos}}" "{{goarch}}" "{{cgo}}" "{{tests}}"

type-diff-goroot-matrix limit="16": build
    systemd-run --user --scope -p MemoryHigh=6G -p MemoryMax=8G -p MemorySwapMax=1G -p TasksMax=512 -p CPUQuota=300% bash -euo pipefail -c 'gomlgo_src=$(bash toolchain/go.sh --source-root) && for target in "linux amd64" "linux arm64" "windows amd64"; do set -- $target; GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_type_goroot_diff/gomlgo_type_goroot_diff acceptance std "{{limit}}" "$gomlgo_src" "" "$1" "$2" 0 none || exit $?; done'

type-diff-goroot-tests limit="16" tests="external": build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && systemd-run --user --scope -p MemoryHigh=6G -p MemoryMax=8G -p MemorySwapMax=1G -p TasksMax=512 -p CPUQuota=300% env GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_type_goroot_diff/gomlgo_type_goroot_diff acceptance std "{{limit}}" "$gomlgo_src" "" linux amd64 0 "{{tests}}"

type-mutate-diff limit="25": build
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_type_mutate_diff/gomlgo_type_mutate_diff testdata/typecheck/valid "{{limit}}" "$(pwd)/_artifact/gomlgo-type-diff/failures"

diff-goroot: build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_scan_diff/gomlgo_scan_diff "$gomlgo_src"
    gomlgo_src=$(bash toolchain/go.sh --source-root) && GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff ast-comments "$gomlgo_src"

parse-diff: build
    GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff parse-acceptance testdata/valid

parse-diff-goroot: build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff parse-acceptance "$gomlgo_src"

ast-shape-goroot: build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff ast-shape "$gomlgo_src"

ast-position-goroot: build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff ast-position "$gomlgo_src"

ast-comments-goroot: build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_parse_diff/gomlgo_parse_diff ast-comments "$gomlgo_src"

mutate-diff limit="25": build
    gomlgo_src=$(bash toolchain/go.sh --source-root) && GOMLGO_ORACLE="$(pwd)/_artifact/gomlgo/oracle" _artifact/gomlgo-build/bin/cmd/gomlgo_mutate_diff/gomlgo_mutate_diff "$gomlgo_src" "{{limit}}" "$(pwd)/_artifact/gomlgo-diff/failures"

smoke: build
    bash tools/smoke.sh

ci: fmt-check native-test test diff type-diff smoke

clean:
    rm -rf _artifact
