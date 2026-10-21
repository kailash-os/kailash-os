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
#   tools/build-arm-images.sh 2026.01-alpha.1 [profile] [iso|qemu] [upload]
#
# Default: every TABLE-scoped profile (minimal, headless-agent) in BOTH
# formats at $TAG, no upload (files left in ./release-arm/ with an
# arm-local checksum sheet SHA256SUMS-aarch64-local — suffixed, so it can
# never clobber the release's canonical SHA256SUMS; the release-side
# attach concatenates the sheets). The redteam-ai profile has no aarch64
# row in the matrix table (the KA-36 slice-2 residual, kailash-os#36), so
# it is NOT in the default expansion — the images-release-completeness
# gate (KA-33 slice 3, kailash-os#200) enforces that the default expands
# exactly the table's aarch64 rows and nothing else.
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
  PROFILES=(minimal headless-agent)
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
    echo "== build: $ref at $TAG =="
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
      echo "   the artefact is on the release"
    fi
  done
done

echo "== SHA256SUMS-aarch64-local =="
cd "$OUTDIR"
# The arm-local sheet is SUFFIXED (ko#200): it concatenates INTO the
# release's canonical SHA256SUMS on the release side; never a shared
# unsuffixed name that could clobber it. The checksum run is STRICT:
# empty expansions abort loudly instead of silently writing a blank sheet
# (the old 2>/dev/null || true swallow).
ARTS=()
for f in ./*.iso ./*.qcow2; do
  if [ -f "$f" ]; then ARTS+=("$f"); fi
done
if [ "${#ARTS[@]}" -eq 0 ]; then
  echo "no image artefacts in $OUTDIR — the checksum step has no input" >&2
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${ARTS[@]}" > SHA256SUMS-aarch64-local
else
  shasum -a 256 "${ARTS[@]}" > SHA256SUMS-aarch64-local
fi
cat SHA256SUMS-aarch64-local
echo "done — the artefacts and SHA256SUMS-aarch64-local are in $OUTDIR/; rerun with 'upload' to send them to the release"
