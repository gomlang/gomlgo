# Repository guidelines

gomlgo is an independent Go frontend and interpreter written in GoML. Sources
use `.goml`; native runtime helpers and the independent reference oracle use Go.
Read `README.md` for compatibility targets and execution limits.

Use `just toolchain` to install the checksum-pinned released GoML toolchain, or
set `GOML` to an installed toolchain executable. Keep its executable-relative
resources intact. Use Go 1.26.x on `PATH` and select the same reference executable
with `GOMLGO_GO` when necessary. A sibling compiler repository is not required.

Run `just fmt` after changing GoML sources and before testing or committing.
Use `just test` for GoML tests, `just native-test` for Go race tests, `just diff`
and `just type-diff` for local differential cases, and `just smoke` for the CLI
and interpreter. Run `just ci` for integration or build changes. The broader
GOROOT, official and mutation corpora remain explicit recipes.

Keep build products under `_artifact/`. Do not add code comments. Preserve
recoverable diagnostics, source byte offsets and explicit compatibility limits.
Avoid production imports of Go's scanner/parser/type checker; the oracle is
test-only. Do not hand-edit copied compiler-product fixtures; refresh them from
generated upstream output and retain provenance and hashes.

Use concise Conventional Commits. Keep implementation and test changes in
separate commits. Preserve the source project's ownership terms; do not add or
change a license without explicit authorization.
