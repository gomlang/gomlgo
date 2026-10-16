# gomlgo

`gomlgo` is an independent GoML module implementing a Go 1.26 scanner, recursive-descent parser, package type checker, and source importer. The language and standard-library compatibility target is Go 1.26.x, matching the GoML toolchain baseline. Production code does not call `go/scanner`, `go/parser`, `go/types`, `go/constant`, or `go/importer`.

The frontend accepts source as `std::bytes::Bytes`, preserving invalid UTF-8 and physical byte offsets. The scanner implements the complete Go token set, literal validation, comments, BOM and NUL handling, Unicode identifiers, and automatic semicolon insertion. Tokens retain kind, literal, start/end offsets, and whether a semicolon is synthetic.

The parser is organized as declarations/files, types, expressions, statements, comments, and build constraints. It uses a comment-skipping token cursor, explicit recovery points, progress guards, a diagnostic cap, and a nesting guard. Its normalized AST mirrors every Go 1.26 `go/ast` expression, statement, declaration, field, comment, and file node used by `parser.ParseFile` with `ParseComments | AllErrors | SkipObjectResolution`. Positions are 0-based physical byte offsets and `-1` represents `token.NoPos`.

The type checker lowers the parser AST into a strongly typed syntax arena with stable file and node IDs. Types, objects, packages, scopes, constants, selections, instances, and initialization dependencies use ID-based arenas and side tables. It supports package and file scopes, declarations, imports, named and alias types, interfaces and method sets, constants, expressions and builtins, generics and inference, statements and control flow, initialization ordering, and Go 1.26 `new(expr)` behavior. Constants use arbitrary-precision integers and rationals plus a 512-bit binary floating representation for values that exceed the exact rational resource boundary.

Syntax paths are opaque, immutable handles. Use `node.path.to_string()` to render them and `syntax::empty_path()` or `syntax::text_path(value)` when constructing syntax nodes.

`SyntaxArena.nodes` is a contiguous `Vec[SyntaxNode]`, with each node ID equal to its array index. Use `syntax::get_kind` for kind-only queries, `syntax::get_node` for a complete optional node value, and `syntax::has_node` to check an ID; invalid IDs remain recoverable.

Type facts retain independent constant snapshots. `FactConstant::SmallInt(i64)` stores signed 64-bit integers directly; larger values retain copied arbitrary-precision storage. Use `type_fact_constant` and `type_fact_constant_kind` to read the exact value and kind across storage variants.

The source importer evaluates `//go:build` and `// +build` constraints, GOOS/GOARCH and release tags, custom tags, cgo selection, platform filename suffixes, import cycles, and source dependencies. It selects ordinary, internal-test, and external-test package sources separately. Its default target is `linux/amd64`, cgo disabled, with the selected Go toolchain’s `GOROOT/src` as the source root. Each load configuration captures its source root once; failure to discover a compatible toolchain is reported when an import needs it.

`checker::CheckConfig` exposes `go_version`, target `sizes`, `ignore_func_bodies`, `fake_import_c`, `disable_unused_import_check`, `enable_alias`, and explicit import availability/failure inputs. The default is Go 1.26, gc/amd64 sizes, function bodies enabled, cgo import emulation disabled, unused-import checks enabled, and materialized aliases.

`oracle/` is test-only Go code built with the selected Go 1.26.x executable. It exposes `version`, `scan`, `parse-file`, `parse-expr`, `type-check-package`, and `constant-eval` over stdin/stdout JSON. Type-check requests contain a package path, Go version, target, source files, and checker configuration; responses contain diagnostics, package metadata, normalized scopes and objects, and all `go/types.Info` sections. The test protocol also has `collect_info`; acceptance-only GOROOT runs set it to false so the oracle does not normalize data that will not be compared. GoML differential runners invoke the oracle only as an independent reference process.

## Commands

This standalone repository requires Linux amd64, Go 1.26.x, a C compiler for
race tests, `just`, Bash, curl, tar and sha256sum. It builds with the released
GoML 0.1.63 toolchain; no GoML compiler checkout is needed.

Install the checksum-pinned release with `just toolchain`, then run `just build`
or `just test`. The installer writes only to `_artifact/`. Set `GOML` to an
absolute path to use an existing compatible GoML installation instead. Its
executable-relative `lib/` and finalized compiler world must be present.

Set `GOMLGO_GO` to a Go 1.26.x executable to select the oracle, source importer,
interpreter and GOROOT differential corpus together. When unset, selection uses
`/usr/lib/go-1.26/bin/go` if present, then `go` on `PATH`; an explicitly empty
value selects `go` on `PATH`. The GoML build also uses `go` on `PATH`, so put the
selected Go toolchain there. Automatic Go toolchain switching is disabled for
oracle and interpreter operations. Build and test concurrency default to two;
set `GOML_BUILD_JOBS` and `GOML_TEST_JOBS` to override them.

Run from this repository root. `just ci` runs formatting, native Go race tests,
the complete GoML suite, local parser/type differential cases and executable
smoke checks. Broader GOROOT, mutation and official corpora remain explicit
commands; recipes using `systemd-run` additionally require a user systemd session.

```bash
just toolchain
just ci
just test
just build
just diff
just type-test
just type-diff
just type-diff-official
just type-diagnostics-official
just type-diff-goroot 10 std
just type-diff-goroot -1 cmd acceptance
just type-diff-goroot -1 std info
just type-diff-goroot 1 std acceptance linux arm64 0 none
just type-diff-goroot-matrix 16
just type-diff-goroot-tests 16 internal
just type-diff-goroot-tests 16 external
just type-mutate-diff 25
just diff-goroot
just parse-diff-goroot
just ast-shape-goroot
just ast-position-goroot
just ast-comments-goroot
just mutate-diff 25
```

`just build` writes the CLI and differential runners under `_artifact/gomlgo-build/bin/cmd`. From the repository root:

```bash
_artifact/gomlgo-build/bin/cmd/gomlgo/gomlgo scan FILE
_artifact/gomlgo-build/bin/cmd/gomlgo/gomlgo parse FILE
_artifact/gomlgo-build/bin/cmd/gomlgo/gomlgo parse-expr 'a + b*c'
_artifact/gomlgo-build/bin/cmd/gomlgo/gomlgo check FILE...
_artifact/gomlgo-build/bin/cmd/gomlgo/gomlgo check-package DIRECTORY
_artifact/gomlgo-build/bin/cmd/gomlgo/gomlgo run FILE [-- PROGRAM_ARGS...]
```

## Single-file interpreter

`gomlgo run` accepts exactly one explicit `.go` file. The file must declare `package main` and define `main.main`. Only that file is interpreted: other files in the directory, local packages, third-party modules, cgo, and assembly are outside the current execution scope. Imports are limited to Go 1.26 standard-library packages.

The execution loader uses the [selected Go toolchain](#commands) for environment and standard-library dependency metadata and native image builds. Execution rejects versions outside Go 1.26.x.

User functions are lowered to typed bytecode and executed by the GoML VM; `gomlgo run` is not a wrapper around `go run`. The VM supports package initialization, functions and closures, control flow, arrays, structs, pointers, slices, maps, methods, interfaces, type assertions and switches, method values and expressions, variadic calls, generic function and method instantiation, string, byte-slice, rune-slice, and rune conversions, and `defer`, `panic`, and `recover`. Runtime faults use the same panic unwinding path and therefore execute deferred calls and can be recovered. A cooperative scheduler implements goroutines, buffered and unbuffered channels, close, channel range, seeded select, and deadlock detection. `--seed` selects deterministic select choices, `--max-goroutines` limits scheduler growth, and `--max-steps` sets a positive instruction limit or `-1` for no limit.

Generated files named `.goml.go` or `goml_generated.go` use the same standard-library source declarations as ordinary `.go` files. Their filenames do not select alternate type definitions. Native image builds sharing a cache key are serialized with a process lock; failed builds release the lock and remove their staging files.

Standard-library bodies are never interpreted. Used package functions, including concrete generic instances, are linked to stable native call IDs and a generated Go registry. Generic standard-library calls inside interpreted generic functions are specialized with the outer function's concrete type arguments. The execution image places the VM and registry in one process and passes opaque values that directly contain `reflect.Value`; there is no RPC, pipe protocol, serialization, session, or remote object-handle table.

Exported standard-library named structs are registered with their real Go types, so their zero values and addressable pointer receivers retain Go semantics. Used standard-library methods are bound as static method expressions, and function values returned by native calls are invoked directly through the same asynchronous `reflect.Value` bridge. Native slice results preserve both length and capacity. This covers compiler-generated task-scope code using `sync.Mutex`, `sync.WaitGroup`, `context.Context`, and `context.CancelFunc`. The checked-in `gomlc` lexical task scope product executes with output identical to Go 1.26; its source commit and generated file hashes are recorded in the [fixture provenance](testdata/execute/pure/generated_task_scope/SOURCE.md).

Native calls run on host goroutines and wake the VM through a completion queue. User closures cross the boundary as direct callback tokens and execute on the VM scheduler, preserving captures, panic, and exit behavior. The image generator emits concrete proxies for exported standard-library interfaces and type shells for exported, non-generic user structs with supported fields, including struct tags. Native channels such as values returned by `time.After` participate in blocking receive and receive-only select. `os.Args` contains the image path followed only by arguments after `--`.

The native value boundary currently supports scalar values, recursively supported slices, concrete function callbacks, selected exported interfaces, non-generic user structs whose fields use supported value types, and receive-capable native channels. Unsupported package variables other than `os.Args`, interface methods with generic or variadic signatures, native channel send/mixed native-and-interpreted select, user aggregate pointers requiring persistent writeback identity, `unsafe`, cgo, and third-party packages are diagnosed rather than approximated. Native code has the same operating-system authority as an ordinary Go program, so the interpreter is not a security sandbox.

## Differential checks

The parser differential binary accepts `parse-acceptance`, `ast-shape`, `ast-position`, `ast-comments`, or `diagnostic-strict`. A mismatch reports the file, normalized AST path, surrounding node offset, expected value, and actual value.

Mutation differential failures are stored under `_artifact/gomlgo-diff/failures/<hash>/` with `input.go`, `gomlgo.json`, `oracle.json`, and `diff.txt`.

Type-check mutation failures are stored under `_artifact/gomlgo-type-diff/failures/<hash>/` with `request.json`, `sources/`, `gomlgo.json`, `oracle.json`, and `diff.txt`.

The GOROOT type differential recipes run their checker in a user systemd scope with `MemoryHigh=6G`, `MemoryMax=8G`, `MemorySwapMax=1G`, `TasksMax=512`, and `CPUQuota=300%`. They accept GOOS, GOARCH, cgo, and `none|internal|external` test-package modes, and reset the loader session every 16 target packages. `acceptance` compares accept/reject status and diagnostics needed to determine it; `info` additionally compares normalized `TypeInfo`.

The official type corpus recipes also run in a resource-limited user systemd scope. They invoke one checker process per source file so retained dependency state is released between cases; the hard limits are 10 GiB memory, 2 GiB swap, 256 tasks, and 300% CPU.

`testdata/invalid/` contains recovery smoke cases. `testdata/regressions/` contains minimized differential failures and is checked by `just diff`.

## Compatibility coverage

Differential results depend on the checked-out sources, exact Go 1.26 patch release, target, and selected corpus. Run `bash toolchain/go.sh version` to record the selected reference version. Fixtures that explicitly request older Go language versions remain version-gating regression tests. Use the commands above to obtain current results; historical file counts and zero-difference totals are not a compatibility guarantee.

| Area | Comparison | Reproduce |
| --- | --- | --- |
| Scanner and parser fixtures | Tokens, acceptance, AST shape, positions, and comments | `just diff` |
| GOROOT scanner and parser | Tokens and normalized AST including comments | `just diff-goroot` |
| Local type checking | Acceptance, diagnostics, and normalized type information | `just type-diff` |
| Official Go type corpus | Normalized type information and exact diagnostics | `just type-diff-official` and `just type-diagnostics-official` |
| Standard-library packages | Acceptance or normalized type information | `just type-diff-goroot -1 std acceptance` or `just type-diff-goroot -1 std info` |
| Go command packages | Acceptance | `just type-diff-goroot -1 cmd acceptance` |
| Target and test-package samples | Selected platforms and internal/external tests | `just type-diff-goroot-matrix` and `just type-diff-goroot-tests` |
| Mutation samples | Parser and type-checker regressions | `just mutate-diff` and `just type-mutate-diff` |

Strict parser diagnostic count and message parity for invalid files is best-effort. Complete `cmd/...` type information, the full cgo-enabled corpus, broad internal/external test-package corpora, and full GOOS/GOARCH matrices are not established compatibility guarantees. Interpreter execution has the separate limits described above.

## Repository origin

This repository preserves the filtered `gomlgo/` history from
[gomlang/goml](https://github.com/gomlang/goml), split at
`968667b0732beb8ca6f92795d1a4cbe9feac5dde`. Compiler-product fixtures used by the
independent tests are checked in here with provenance; tests do not read a
sibling compiler checkout.

## Ownership and license

As in the source project, no open-source license is currently granted. All
rights remain reserved by the author until a license is explicitly provided.
