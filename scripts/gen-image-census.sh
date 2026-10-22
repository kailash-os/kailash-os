#!/usr/bin/env bash
# gen-image-census.sh — regenerate tests/images-census.json (KA-28, #28).
#
# Runs the SAME eval-side walker the budget leg runs
# (images/closure-walk.nix over images/generator.nix's per-target
# toplevels) via a direct getFlake probe and rewrites the committed
# snapshot's target counts the eval leg asserts against. Name-set drift
# (a manifest merge or a pin bump) turns the leg red until this
# regenerates the snapshot in the same cycle.
#
# Local run (aarch64-darwin lane box): pure eval, seconds, NO builds and
# NO narinfo HTTP — the closure-name census is pure derivation eval; the
# MASS numbers are the build-side images-budget legs' business
# (closureInfo NarSize sums on the hosted builder). Run from repo root.
set -euo pipefail

OUT="tests/images-census.json"

COUNTS=$(nix-instantiate --eval --strict --json --expr '
  let
    fl = builtins.getFlake (toString ./.);
    lib = fl.inputs.nixpkgs.lib;
    gen = import (fl + "/images/generator.nix") {
      inherit lib;
      pkgsLinux = import fl.inputs.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        config.allowInsecurePredicate = p: true;
        overlays = lib.optionals
          (fl.inputs.kailash-packages ? "overlays" && (fl.inputs.kailash-packages.overlays ? "default"))
          [ fl.inputs.kailash-packages.overlays.default ];
      };
      nixos-generators = fl.inputs.nixos-generators;
    };
    walk = import (fl + "/images/closure-walk.nix") { inherit lib; };
  in builtins.mapAttrs (_: tl: { count = (walk tl).count; }) gen.toplevels
')

python3 - "$OUT" "$COUNTS" <<'PY'
import json, sys
out, counts = sys.argv[1], json.loads(sys.argv[2])
doc = json.load(open(out))
doc["targets"] = counts
json.dump(doc, open(out, "w"), indent=2, sort_keys=True)
print("census:", out, "targets:", len(doc["targets"]), "counts:", counts)
PY
