#!/usr/bin/env bash
# Update sources.json to the latest (or given) Restate release.
#
# Hashes are taken from the sha256.sum asset published with each release,
# so the (large) binary archives don't need to be downloaded.
#
# Usage: update.sh [VERSION]
# Requires: curl, jq, nix

set -euo pipefail

repo="restatedev/restate"
sources="$(dirname "$0")/sources.json"

curl_args=(--fail --silent --show-error --location --retry 3)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
fi

if [[ $# -gt 0 ]]; then
    version="${1#v}"
else
    version="$(curl "${curl_args[@]}" "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name | ltrimstr("v")')"
fi

current="$(jq -r '.version' "$sources" 2>/dev/null || echo "")"
if [[ "$version" == "$current" ]]; then
    echo "restate-bin is up to date ($version)"
    exit 0
fi

echo "Updating restate-bin: ${current:-<none>} -> $version"

checksums="$(curl "${curl_args[@]}" "https://github.com/${repo}/releases/download/v${version}/sha256.sum")"

# nix system => upstream target (keep in sync with default.nix)
targets=(
    aarch64-darwin=aarch64-apple-darwin
    aarch64-linux=aarch64-unknown-linux-musl
    x86_64-darwin=x86_64-apple-darwin
    x86_64-linux=x86_64-unknown-linux-musl
)
components=(restate-cli restate-server restatectl)

json="$(jq -n --arg version "$version" '{version: $version, assets: {}}')"

for pair in "${targets[@]}"; do
    system="${pair%%=*}"
    target="${pair#*=}"
    for component in "${components[@]}"; do
        file="${component}-${target}.tar.xz"
        hex="$(awk -v f="$file" '{ sub(/^\*/, "", $2) } $2 == f { print $1 }' <<<"$checksums")"
        if [[ -z "$hex" ]]; then
            echo "error: no checksum for $file in sha256.sum" >&2
            exit 1
        fi
        sri="$(nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "$hex")"
        json="$(jq --arg s "$system" --arg c "$component" --arg h "$sri" '.assets[$s][$c] = $h' <<<"$json")"
    done
done

jq . <<<"$json" >"$sources"
echo "Wrote $sources"
