#!/usr/bin/env bash
# Move the pins in versions.json to an upstream release.
#
#   ./scripts/update.sh              # newest release on GitHub
#   ./scripts/update.sh 0.3.1        # a named release
#   ./scripts/update.sh 0.3.0 --force  # recompute the hashes of the current release
#
# Every URL and hash the packages use lives in versions.json; this script is the
# only thing that writes it. Run it, then let CI build what it pinned.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS="$REPO_ROOT/versions.json"

# The systems the flake builds for, and each one's suffix in the release assets.
SYSTEMS=("x86_64-linux" "aarch64-linux")

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is needed but not on PATH"
}

need curl
need jq
need nix
need nix-prefetch-url

target="${1:-}"
force=false
for arg in "$@"; do
  if [ "$arg" = "--force" ]; then
    force=true
  fi
done
if [ "$target" = "--force" ]; then
  target=""
fi

current="$(jq -r '.version' "$VERSIONS")"

if [ -z "$target" ]; then
  echo "==> Looking up the newest release of storytold/craft-anything…"
  tag="$(curl -fsSL https://api.github.com/repos/storytold/craft-anything/releases/latest | jq -r '.tag_name // empty')"
  [ -n "$tag" ] || die "the GitHub API returned no release tag"
  version="${tag#v}"
else
  version="${target#v}"
fi

echo "==> versions.json pins v${current}; target is v${version}"

if [ "$version" = "$current" ] && [ "$force" = false ]; then
  echo "==> Already at v${version}. Pass --force to recompute its hashes."
  exit 0
fi

# An unpacked archive is hashed the way fetchzip hashes it, so the same string
# works for the from-source build.
unpacked_sri() {
  local url="$1" base32
  base32="$(nix-prefetch-url --unpack "$url" 2>/dev/null)" || die "couldn't fetch $url"
  nix hash convert --to sri --hash-algo sha256 "$base32"
}

file_sri() {
  local url="$1" base32
  base32="$(nix-prefetch-url "$url" 2>/dev/null)" || die "couldn't fetch $url"
  nix hash convert --to sri --hash-algo sha256 "$base32"
}

source_url="https://github.com/storytold/craft-anything/archive/refs/tags/v${version}.tar.gz"
echo "==> Source: $source_url"
source_hash="$(unpacked_sri "$source_url")"
echo "    $source_hash"

# Build one JSON object per system, then fold them together so the file's shape
# stays exactly what pkgs/common.nix expects.
packages_json='{}'
for system in "${SYSTEMS[@]}"; do
  arch="${system%-linux}"
  url="https://github.com/storytold/craft-anything/releases/download/v${version}/craft-anything-${version}-linux-${arch}.deb"
  echo "==> ${system} package: $url"
  hash="$(file_sri "$url")"
  echo "    $hash"
  packages_json="$(jq -c --arg system "$system" --arg url "$url" --arg hash "$hash" \
    '. + {($system): {url: $url, hash: $hash}}' <<<"$packages_json")"
done

tmp="$(mktemp "$VERSIONS.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

jq -n \
  --arg version "$version" \
  --arg source_url "$source_url" \
  --arg source_hash "$source_hash" \
  --argjson packages "$packages_json" \
  '{version: $version, source: {url: $source_url, hash: $source_hash}, packages: $packages}' \
  >"$tmp"

jq -e '.version and .source.url and .source.hash and (.packages | length > 0)' "$tmp" >/dev/null ||
  die "the new versions.json is missing a field"

mv "$tmp" "$VERSIONS"
trap - EXIT

echo "==> versions.json now pins v${version}"
echo "==> Check it with: nix flake check && nix build .#craft-anything-bin .#craft-anything-src"
