#!/usr/bin/env bash
set -euo pipefail

test "$#" = 0
test "$(uname -s)" = Linux
test "$(uname -m)" = x86_64
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repository_root/toolchain/goml.env"
prefix="$repository_root/_artifact/toolchain"
asset="goml-$GOML_VERSION-linux-amd64.tar.gz"
cache="$repository_root/_artifact/downloads"
archive="$cache/$asset"

if test -x "$prefix/bin/goml" \
    && test -x "$prefix/bin/gomlc" \
    && test -f "$prefix/lib/compiler/compiler-world-v2.gaf" \
    && test -f "$prefix/.archive-sha256" \
    && test "$(cat "$prefix/.archive-sha256")" = "$GOML_SHA256" \
    && test "$("$prefix/bin/goml" version)" = "goml $GOML_VERSION"; then
    exit 0
fi

mkdir -p "$cache"
staging="$(mktemp -d "$repository_root/_artifact/toolchain.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
if ! test -f "$archive" || ! printf '%s  %s\n' "$GOML_SHA256" "$archive" | sha256sum --check --status; then
    curl --fail --location --retry 3 \
        --output "$staging/archive.tar.gz" \
        "https://github.com/gomlang/goml/releases/download/v$GOML_VERSION/$asset"
    printf '%s  %s\n' "$GOML_SHA256" "$staging/archive.tar.gz" | sha256sum --check --status
    mv "$staging/archive.tar.gz" "$archive"
fi
printf '%s  %s\n' "$GOML_SHA256" "$archive" | sha256sum --check --status
mkdir "$staging/prefix"
tar -xzf "$archive" --strip-components=1 -C "$staging/prefix"
test "$("$staging/prefix/bin/goml" version)" = "goml $GOML_VERSION"
"$staging/prefix/bin/goml" __toolchain-finalize --prefix "$staging/prefix"
test -f "$staging/prefix/lib/compiler/compiler-world-v2.gaf"
printf '%s\n' "$GOML_SHA256" > "$staging/prefix/.archive-sha256"
rm -rf -- "$prefix"
mv "$staging/prefix" "$prefix"
