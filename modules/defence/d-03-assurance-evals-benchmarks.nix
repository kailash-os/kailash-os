# Layer DEFENCE — D-3 AI Assurance, Evals & Benchmarks (KA-24, os#24;
# spec §3.5, §9 Phase 6). The §4.5 category module — config-only mount
# on the typed spine (enable + packages at
# kailash.layers.defence.categories.d-03), the KA-13.1 exemplar shape.
#
# Binding table (probed at nixpkgs e7439b6b + packages pin ef70ec4 —
# never assumed id==attr):
#   * huggingface-evaluate → python3Packages.evaluate (evaluate 0.4.6,
#     unbroken — the id is the pypi name `evaluate`; the NATIVE_BINDINGS
#     gate in kailash-packages tests/validate_manifest.py records the
#     same binding, one truth both sides read);
#   * lm-eval-harness → python3Packages.lm-eval (0.4.13, unbroken) —
#     NATIVE with the KA-24 probe-receipt flip landed
#     (kailash-packages#54; the binding is per-id and resolves through
#     the composed nixpkgs on either side of that merge);
#   * deepeval, robustbench, fairlearn, aif360 — manifest-bespoke,
#     derivations NOT landed at this pin → the bare guard drops them
#     (named, per-row); each returns with its lane.
#
# SAFETY: every d-03 row is safety.level "safe" at this revision.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-03;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-03-assurance-evals-benchmarks.installable;

  # The non-bare bindings at this pin (the pypi-name divergences,
  # probed — the python3Packages attrs carry the upstream pypi names).
  attrFor = id:
    {
      "huggingface-evaluate" = pkgs.python3Packages.evaluate or null;
      "lm-eval-harness" = pkgs.python3Packages.lm-eval or null;
    }.${id} or (pkgs."${id}" or null);

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (2 of the 6 rows bind at this
    # pin: huggingface-evaluate + lm-eval-harness via python3Packages;
    # the four pending bespoke rows drop via the guard, named above).
    kailash.layers.defence.categories.d-03.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
