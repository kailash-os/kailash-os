# The derivation-level census walker (KA-28 budget suite, kailash-os#28).
#
# WHAT EVALUATION CAN SEE: a NixOS toplevel's full closure rides its
# buildCommand STRING (store-path placeholders interpolated at derivation
# level — the closure refs the builder script touches), so the census
# harvests the derivation-level input NAMES as path tokens out of that
# string: every /nix/store/<hash>-<name…> it references, deduplicated,
# name-normalized. The HEAVY-package names (seclists, gnuradio, gqrx,
# hackrf-tools, texlive…) are what the exclusion assertions match; the
# token COUNT is the drift signal (a manifest merge or a pin bump
# adds/removes tokens → the budget suite's leg goes red until the
# snapshot is regenerated).
#
# WHAT IT DOES NOT TRY (the hosted-runner lesson, kailash-pkgs-lane-fixes):
# no full-closure build-side walk and no mass arithmetic here — masses are
# BUILD-TIME data (the graph's narSize rows defer until the graphs are
# exported at build time); the MASS budget leg (images-budget in flake.nix)
# reads real NarSize sums from `pkgs.closureInfo` over the already-built
# hosted toplevels instead. This walker stays pure-eval-safe (no readFile
# of drv text, no import-from-derivation, no drv paths baked into env
# vars) and evals in seconds on a 7 GB runner.
{
  lib,
}:
tl:
let
  bc = tl.drvAttrs.buildCommand or "";

  # /nix/store/<32-hex>-<name…> tokens in the build command: the separator
  # form of builtins.split ("…" sep "…" sep …) keeps the name tails as the
  # string elements; regex-matched sublists stay non-strings here.
  pieces = builtins.split "/nix/store/[a-z0-9]+-" bc;
  tails = builtins.filter (p: builtins.isString p && p != "") pieces;
  nameAt = s:
    let m = builtins.match "([A-Za-z0-9+._?=-]+).*" s;
    in if m != null then builtins.head m else null;
  names = lib.unique (builtins.filter (n: n != null) (map nameAt tails));
in {
  count = builtins.length names;
  inherit names;
}