#!/usr/bin/env bash
# tools/split-release-artefact.sh — chunked publishing for over-cap release
# artefacts (KA-33.4, kailash-os#206).
#
# GitHub's release-asset uploads endpoint rejects files >= 2 147 483 648
# bytes ("size must be less than 2147483648"). Every §8.1 matrix artefact
# must still live ON the release: this tool byte-splits the artefact into
# parts under the cap, emits a per-part checksum sheet, and reassembles —
# byte-exact — so the reassembled file's sha256 equals the attested
# subject's digest and `gh attestation verify` passes against the ORIGINAL
# build's attestation records (digest-bound; unchanged by the split).
#
# Usage:
#   split-release-artefact.sh split   <artefact> [outdir]   # parts + SHA256SUMS-parts
#   split-release-artefact.sh join    <parts-dir>           # reassemble + verify ALL
#   split-release-artefact.sh verify  <artefact> <dir>      # consumer one-shot: sha -c parts, digest, ready-for-attestation-check
#   split-release-artefact.sh self-test                     # round-trip proof (multi-part, deterministic blob)
#
# Part size: 1900 MiB (every part under the 2 147 483 648-byte endpoint
# cap with margin). The self-test overrides it to 6 MiB so its round-trip
# crosses THREE parts and proves the reassembly ORDER — the real risk of
# chunked packaging — on a small deterministic blob.
#
# Layout (release-side):
#   <name>.qcow2.part-aa, .part-ab, ...        # 1900 MiB each, last partial
#   SHA256SUMS-parts-<name>.qcow2              # per-part sheet (suffixed; name-collision-proof)
#   <name>.qcow2 (in join mode)                # reassembled, digest-verified
set -euo pipefail

PART_MIB="${SPLIT_PART_MIB:-1900}"
MODE="${1:-}"
case "$MODE" in
  split|join|verify|self-test) ;;
  *) echo "usage: split-release-artefact.sh {split <artefact> [outdir] | join <parts-dir> | verify <artefact> <dir> | self-test}" >&2; exit 2 ;;
esac

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 2; }; }
need_split() { need split; need cat; need sha256sum || need shasum; }

digest() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

sha_check() {
  # sha_check <dir> <sheet>: exit nonzero with a named failure on mismatch
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$1" && sha256sum -c "$2" >/dev/null) || { echo "digest mismatch in $1/$2" >&2; return 1; }
  else
    (cd "$1" && shasum -a 256 -c "$2" >/dev/null) || { echo "digest mismatch in $1/$2" >&2; return 1; }
  fi
}

whole_sheet_for() {
  # echo the sheet name that carries the whole-file line in the repo checkout
  echo "SHA256SUMS"
}

split_mode() {
  local artefact="$1" outdir="${2:-.}"
  # Read the part size LIVE (the self-test shrinks it; a startup-only
  # default would pin 1900 regardless of the env).
  local PART_MIB="${SPLIT_PART_MIB:-1900}"
  [ -f "$artefact" ] || { echo "no such artefact: $artefact" >&2; exit 2; }
  need_split
  mkdir -p "$outdir"
  local base; base="$(basename "$artefact")"
  echo "splitting $base ($(($(stat -f%z "$artefact" 2>/dev/null || stat -c%s "$artefact") / 1024 / 1024)) MiB) into ${PART_MIB} MiB parts -> $outdir"
  rm -f "$outdir/$base".part-* "$outdir/SHA256SUMS-parts-$base"
  # GNU split carries --additional-suffix; BSD (macOS) does not — use it
  # when present, plain numeric suffixes otherwise (the sheet + join work
  # with either; parts NEVER change the byte content they carry).
  if split --additional-suffix=.part /dev/null 2>/dev/null; then
    split -b "${PART_MIB}m" -d -a 3 --additional-suffix=".part" "$artefact" "$outdir/$base.part-"
  else
    split -b "${PART_MIB}m" -d -a 3 "$artefact" "$outdir/$base.part-"
  fi
  # per-part sheet: strict (a missing/garbled part fails loudly)
  local parts=()
  local p
  for p in "$outdir/$base".part-*; do
    [ -f "$p" ] || continue
    parts+=("$p")
  done
  [ "${#parts[@]}" -gt 0 ] || { echo "no parts produced" >&2; exit 1; }
  ( cd "$outdir" && { for p in "${parts[@]}"; do printf '%s  %s\n' "$(digest "$p")" "$(basename "$p")"; done; } > "SHA256SUMS-parts-$base" )
  echo "parts: ${#parts[@]}  sheet: $outdir/SHA256SUMS-parts-$base"
  cat "$outdir/SHA256SUMS-parts-$base"
}

join_mode() {
  local dir="$1"
  [ -d "$dir" ] || { echo "no such dir: $dir" >&2; exit 2; }
  need_split
  # ONE artefact per dir expected: the parts name prefix (drop .part-XXX)
  local sheet
  sheet="$(find "$dir" -maxdepth 1 -name 'SHA256SUMS-parts-*' -type f | sort | head -1)"
  [ -n "$sheet" ] || { echo "no SHA256SUMS-parts-* in $dir" >&2; exit 2; }
  local base; base="$(basename "$sheet")"; base="${base#SHA256SUMS-parts-}"
  local stem="$dir/$base"; stem="${stem%%.part-*}"
  local nparts; nparts="$(find "$stem".part-* -maxdepth 0 -type f | wc -l | tr -d ' ')"
  echo "joining ${nparts} parts -> $stem"
  cat "$stem".part-* > "$stem"
  sha_check "$dir" "$(basename "$sheet")"
  echo "reassembled: $stem"
  echo "whole-file digest: $(digest "$stem")  $(basename "$stem")"
  echo "now verify against the release SHA256SUMS whole-file line, then: gh attestation verify"
}

verify_mode() {
  local artefact="$1" dir="$2"
  # RETURN on failure, never exit: inside an if-condition caller an exit
  # kills the whole shell silently (the errexit rule's sharpest edge —
  # the self-test's corrupt-case probe hit exactly this).
  if [ ! -f "$artefact" ]; then
    echo "no such artefact: $artefact" >&2
    return 2
  fi
  need_split
  local base; base="$(basename "$artefact")"
  if ! sha_check "$dir" "SHA256SUMS-parts-$base"; then
    return 1
  fi
  local whole; whole="$(digest "$artefact")"
  echo "parts OK; whole digest: $whole"
  if [ -f "$dir/SHA256SUMS" ] && grep -q "^$whole  $base\$" "$dir/SHA256SUMS"; then
    echo "WHOLE-FILE DIGEST MATCHES THE RELEASE SHEET — run: gh attestation verify $base -R kailash-os/kailash-os"
    return 0
  fi
  echo "whole digest NOT found in $dir/SHA256SUMS — re-download/re-split before trusting" >&2
  return 1
}

self_test() {
  need_split
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  # Deterministic 13 MiB blob (no urandom dependency: a fixed arithmetic
  # pattern); at the 6 MiB test part size the round trip crosses THREE
  # parts and proves the reassembly ORDER.
  python3 - "$tmp/blob.bin" <<'PY'
import sys
with open(sys.argv[1], "wb") as f:
    f.write(bytes((i * 37 + 11) % 256 for i in range(13 * 1024 * 1024)))
PY
  local d1="$tmp/split" d2="$tmp/join"
  # The env-assignment-prefix is dropped by some shells/wrappers — set it
  # plainly (the known VAR=x cmd trap from the lane notes).
  SPLIT_PART_MIB=6
  split_mode "$tmp/blob.bin" "$d1" >/dev/null
  unset SPLIT_PART_MIB
  local nparts; nparts="$(find "$d1" -maxdepth 1 -name '*.part-*' -type f | wc -l | tr -d ' ')"
  [ "$nparts" -ge 3 ] || { echo "self-test FAILED: expected >=3 parts at the 6 MiB test size, got $nparts" >&2; exit 1; }
  mkdir -p "$d2"; cp "$d1"/*.part-* "$d1"/SHA256SUMS-parts-* "$d2/"
  printf '%s  blob.bin\n' "$(digest "$tmp/blob.bin")" > "$d2/SHA256SUMS"
  join_mode "$d2" >/dev/null
  verify_mode "$d2/blob.bin" "$d2" >/dev/null
  # corruption case: flip a byte in one part's copy and expect verify to FAIL
  local d3="$tmp/bad"; mkdir -p "$d3"; cp "$d2"/*.part-* "$d3"; cp "$d2"/SHA256SUMS-parts-* "$d3"
  local bad_part; bad_part="$(find "$d3" -maxdepth 1 -name '*.part-*' -type f | sort | head -1)"
  printf 'x' | dd of="$bad_part" bs=1 seek=100 conv=notrunc status=none
  if verify_mode "$d2/blob.bin" "$d3" >/dev/null 2>&1; then
    echo "self-test FAILED: corrupted parts were not detected" >&2
    exit 1
  fi
  echo "self-test: OK ($nparts-part round-trip, order-proven, digest-matched, corrupted part detected)"
  trap - EXIT
  rm -rf "$tmp"
}

case "$MODE" in
  split)    shift; split_mode "$@" ;;
  join)     shift; join_mode "$@" ;;
  verify)   shift; verify_mode "$@" ;;
  self-test) self_test ;;
esac
