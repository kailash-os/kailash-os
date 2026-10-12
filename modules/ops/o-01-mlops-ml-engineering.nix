# Layer OPS — O-1 MLOps & ML Engineering Suite (KA-08.1, ko#105; plan §3.5,
# §9 Phase 3). The §4.5 category module, config-only on the §3.6 typed
# spine (modules/base/layer-tree.nix — the per-id option-decl tree; the
# same mount the exemplar modules/classic/c-01-information-gathering.nix
# defines). The spine owns enable + packages at
# kailash.layers.ops.categories.o-01 (the SHORT manifest id — the tree
# keys categories by the §3.6 census ids; the module FILE keeps the
# manifest's long id); this module declares NOTHING there — it consumes
# the spine members:
#
#   enable   — the category switch (spine default false; profiles opt
#              in): the O-1 MLOps and ML Engineering category — the
#              versioning/CLI tooling and the DS stack (dvc, git-lfs,
#              wandb, pandas, polars, scikit-learn, numpy, scipy,
#              xgboost, lightgbm; the bespoke overlay rows when the
#              packages overlay is composed). MLflow is NOT in this
#              package set — it ships as the service module
#              (services.kailash.mlflow). Nothing installs until enabled
#              (§4.5 opt-in by default).
#   packages — the generated, manifest-driven install set
#              (config-assigned below; hosts compose/append on the spine
#              option — never redefine).
#
# DATA CONTRACT: the default package list is GENERATED (§4.5 — the
# manifest is the only hand-maintained registry). The generator
# (tools/gen-category-packages.py, mirror-paired with kailash-packages)
# selects the category's manifest rows and emits their STRUCTURE:
#
#   * native rows  → pkgs attr PATHS in the generated file; THIS module
#     resolves them ?-guarded against its own pkgs, so host evaluation
#     stays green at revisions/pins where an attr moves (divergence —
#     wandb-cli → python3Packages.wandb at this pin — lives in the
#     generator's NATIVE_ATTRS table, probed per pin, never assumed);
#   * bespoke rows → emitted WITH their manifest derivation paths;
#     resolved here by id through the packages overlay (the OS flake
#     composes it when kailash-packages ships overlays.default), guarded
#     ?-by-id so revisions without the overlay evaluate the native subset;
#   * module rows  → NEVER here (the row's own service module owns them —
#     mlflow ships as services.kailash.mlflow, ./mlflow-service.nix);
#   * safety.level == "exp" rows → NEVER in any package list (§11.2 — the
#     double-key gate owns exp routing; the generator refuses to emit
#     them).
#
# The committed files under modules/ops/generated/ are pure generator
# emit, drift-checked EVERY PR by checks.o-01-generated-drift (generator
# run against the PINNED manifest through the flake input == committed ||
# red).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.ops.categories.o-01;

  # The generator's committed emit = pure structure (no package attrs).
  generated =
    (import ./generated/o-01-mlops-ml-engineering.nix {
      inherit lib;
    }).o-01-mlops-ml-engineering;

  # Resolver, §4.5: every attr path ?-guarded (green eval at revisions
  # where the overlay is absent or a native attr moves).
  resolveNative = path:
    if lib.attrByPath path null pkgs != null then [ (lib.getAttrFromPath path pkgs) ] else [ ];
  resolveBespoke = row:
    if lib.attrByPath [ row.id ] null pkgs != null
    then [ (lib.getAttrFromPath [ row.id ] pkgs) ]
    else [ ];

  # The manifest-driven install set = the generated rows resolved.
  # Hosts compose/append on the spine option; never redefine — and never
  # a config-assignment of cfg.packages back into the tree (a mkIf
  # self-assignment re-enters the layers merge mid-collection,
  # eval-probed at this pin).
  installSet = lib.flatten
    (map resolveNative generated.native ++ map resolveBespoke generated.bespoke);
in
{
  config = {
    # The manifest-driven install set (10 native rows resolved on the
    # pinned nixpkgs + the bespoke overlay rows when the overlay is
    # composed; the generator + drift check own the regeneration).
    kailash.layers.ops.categories.o-01.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default. MLflow is NOT in this set — it ships as
    # the service module (services.kailash.mlflow); exp-class rows are
    # absent from the tree by construction (the lab-mode gate owns that
    # surface).
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
