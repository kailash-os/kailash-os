#!/usr/bin/env bash
# tools/build-arm-images.sh — the LOCAL aarch64-linux image builder (KA-36).
#
# The standing arch strategy (user decision, 2026-10-13, recorded on
# kailash-os#198): x86_64-linux images build on HOSTED runners
# (.github/workflows/release-images.yml); aarch64-linux images build LOCALLY
# on the lane Mac (Apple Silicon runs nixpkgs.aarch64-linux derivations
# natively — no emulation, no remote builder).
#
# Usage (from a clone at the tag):
#   tools/build-arm-images.sh 2026.01-alpha.1 [minimal|redteam-ai|headless-agent] [iso|qemu] [upload]
#
# Default: every profile in BOTH formats at $TAG, no upload (files left in
# ./release-arm/ with a SHA256SUMS sheet).
set -euo pipefail

TAG="${1:?usage: build-arm-images.sh <tag> [profile] [format] [upload]}"
PROFILE="${2:-all}"
FORMAT="${3:-all}"
UPLOAD="${4:-}"

cd "$(git rev-parse --show-toplevel)"
OUTDIR="release-arm"
mkdir -p "$OUTDIR"

PROFILES=()
if [ "$PROFILE" = "all" ]; then
  PROFILES=(minimal redteam-ai headless-agent)
else
  PROFILES=("$PROFILE")
fi

FORMATS=()
if [ "$FORMAT" = "all" ]; then
  FORMATS=(iso qemu)
else
  FORMATS=("$FORMAT")
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
need nix
need sha256sum || need shasum

for prof in "${PROFILES[@]}"; do
  for fmt in "${FORMATS[@]}"; do
    ref="kailash-images-${fmt}-aarch64-${prof}"
    echo "== building $ref at $TAG =="
    nix build "github:kailash-os/kailash-os/${TAG}#${ref}" -L --no-link --print-out-paths | tail -1 > "$OUTDIR/${ref}.path"
    OUT="$(cat "$OUTDIR/${ref}.path")"
    ART="$(find "$OUT" \( -name '*.iso' -o -name '*.qcow2' -o -name 'nixos-*' \) -type f | head -1)"
    [ -n "$ART" ] || { echo "no image artefact in $OUT" >&2; exit 1; }
    BASE="$(basename "$ART")"
    SUFFIX="${BASE##*.}"
    DEST="$OUTDIR/kailash-${TAG}-aarch64-${prof}-${fmt}.${SUFFIX}"
    cp "$ART" "$DEST"
    echo "   -> $DEST"
    if [ "$UPLOAD" = "upload" ]; then
      gh release upload "$TAG" "$DEST" --clobber
      echo "   uploaded to the release"
    fi
  done
done

echo "== SHA256SUMS =="
cd "$OUTDIR"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum ./*.iso ./*.qcow2 2>/dev/null > SHA256SUMS || true
else
  shasum -a 256 ./*.iso ./*.qcow2 2>/dev/null > SHA256SUMS || true
fi
cat SHA256SUMS
echo "done — artefacts + SHA256SUMS in $OUTDIR/ (re-run with 'upload' to push them to the release)"
