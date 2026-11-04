#!/usr/bin/env bash
set -euo pipefail

# scripts/update.sh - Update craft-anything-nix to the latest upstream release

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMON_NIX="$REPO_ROOT/pkgs/common.nix"

echo "==> Checking latest release for storytold/craft-anything..."
TARGET_VER="${1:-}"

if [ -z "$TARGET_VER" ]; then
  LATEST_JSON=$(curl -sSL "https://api.github.com/repos/storytold/craft-anything/releases/latest")
  TARGET_TAG=$(echo "$LATEST_JSON" | jq -r .tag_name)
  TARGET_VER="${TARGET_TAG#v}"
fi

echo "==> Target version: $TARGET_VER (tag: v$TARGET_VER)"

CURRENT_VER=$(grep -E 'version = "[^"]+"' "$COMMON_NIX" | head -n1 | sed -E 's/.*version = "([^"]+)".*/\1/')
echo "==> Current version in common.nix: $CURRENT_VER"

if [ "$CURRENT_VER" = "$TARGET_VER" ] && [ "${2:-}" != "--force" ]; then
  echo "==> Already up to date! Pass --force as second argument to recompute hashes."
  exit 0
fi

echo "==> Prefetching release assets and computing SRI hashes..."

# 1. Source Tarball Hash
SRC_URL="https://github.com/storytold/craft-anything/archive/refs/tags/v${TARGET_VER}.tar.gz"
echo "  -> Fetching source: $SRC_URL"
SRC_HASH=$(nix hash convert --to sri --hash-algo sha256 "$(nix-prefetch-url --unpack "$SRC_URL" 2>/dev/null)")
echo "     SRC_HASH: $SRC_HASH"

# 2. x86_64 .deb Hash
X86_DEB_URL="https://github.com/storytold/craft-anything/releases/download/v${TARGET_VER}/craft-anything-${TARGET_VER}-linux-x86_64.deb"
echo "  -> Fetching x86_64 deb: $X86_DEB_URL"
X86_HASH=$(nix hash convert --to sri --hash-algo sha256 "$(nix-prefetch-url "$X86_DEB_URL" 2>/dev/null)")
echo "     X86_64 DEB_HASH: $X86_HASH"

# 3. aarch64 .deb Hash
AARCH64_DEB_URL="https://github.com/storytold/craft-anything/releases/download/v${TARGET_VER}/craft-anything-${TARGET_VER}-linux-aarch64.deb"
echo "  -> Fetching aarch64 deb: $AARCH64_DEB_URL"
AARCH64_HASH=$(nix hash convert --to sri --hash-algo sha256 "$(nix-prefetch-url "$AARCH64_DEB_URL" 2>/dev/null)")
echo "     AARCH64 DEB_HASH: $AARCH64_HASH"

echo "==> Updating $COMMON_NIX..."

# Update version
sed -i -E "s/version = \"[^\"]+\"/version = \"$TARGET_VER\"/" "$COMMON_NIX"

# Update srcHash
sed -i -E "s|srcHash = \"sha256-[^\"]+\"|srcHash = \"$SRC_HASH\"|" "$COMMON_NIX"

# Update x86_64 debHash
sed -i -E "s|x86_64-linux = \"sha256-[^\"]+\"|x86_64-linux = \"$X86_HASH\"|" "$COMMON_NIX"

# Update aarch64 debHash
sed -i -E "s|aarch64-linux = \"sha256-[^\"]+\"|aarch64-linux = \"$AARCH64_HASH\"|" "$COMMON_NIX"

echo "==> Successfully updated common.nix to version $TARGET_VER!"
echo "==> Verify with: nix flake check"
