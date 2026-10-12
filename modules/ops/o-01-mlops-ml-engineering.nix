# Layer OPS — O-1 MLOps & ML Engineering Suite (KA-08.1, ko#105; plan §3.5,
# §9 Phase 3). The §4.5 category-module shape — the same contract the
# wave-5/6 category modules mount at:
#
#   options.kailash.layers.ops.categories.o-01-mlops-ml-engineering = {
#     enable   — the category switch (default OFF; profiles opt in);
#     packages — the generated, manifest-driven install set (hosts append;
#                never redefine);
#   };
#   config (mkIf enable) installs it.
#
# DATA CONTRACT: the default package list is GENERATED from the pinned
# packages manifest (manifest/tools.yaml) — never hand-edited. The
# generator (tools/gen-category-packages.py in kailash-packages) selects
# the category's manifest rows: safety.level == "exp" rows never reach a
# package list (the §11.2 double-key gate owns exp routing); module-status
# rows never reach a package list (the row's own service module owns them
# — mlflow → services.kailash.mlflow); native rows resolve on the pinned
# nixpkgs (attr divergence recorded per row in the generated-file header)
# and form the committed list in modules/ops/generated/; bespoke rows
# (bentoml, feast, kedro, kedro-datasets) resolve through the packages
# overlay the OS flake composes, guarded by `?` so host evaluation stays
# green at revisions without it.
#
# The generator emit is drift-checked every PR by the root flake's
# checks.o-01-options (generator run against the pinned manifest ==
# committed list). The manifest stays the only hand-maintained registry
# (§4.5).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kailash.layers.ops.categories.o-01-mlops-ml-engineering;

  # Generated native-row list (modules/ops/generated/, the eval-side
  # source — the CI drift gate proves generator == committed).
  o-01-generated =
    (import ./generated/o-01-mlops-ml-engineering.nix {
      inherit lib pkgs;
    }).o-01-mlops-ml-engineering;

  # §4.5 bespoke rows resolve through the packages overlay, guarded: at
  # revisions without the overlay the category evaluates with the native
  # subset (the §4.5 cross-repo rule — the OS flake composes the overlay
  # when kailash-packages ships overlays.default).
  bespokePackages = lib.flatten (
    lib.optionals (pkgs ? bentoml) (
      [
        pkgs.bentoml
        pkgs.feast
        pkgs.kedro
      ]
      ++ lib.optionals (pkgs ? "kedro-datasets") [ pkgs."kedro-datasets" ]
    )
  );

  # The bespoke rows ride the option DEFAULT (the §4.5 merge contract:
  # hosts append via the typed option, never a config-assignment into the
  # freeform-carried tree — a mkIf self-assignment of cfg.packages would
  # re-enter the layers merge mid-collection).
  o-01-packages = o-01-generated ++ bespokePackages;
in
{
  options.kailash.layers.ops.categories.o-01-mlops-ml-engineering = {
    enable = lib.mkEnableOption ''
      the O-1 MLOps and ML Engineering category (KA-08.1): the
      versioning/CLI tooling and the DS stack (dvc, git-lfs, wandb, pandas,
      polars, scikit-learn, numpy, scipy, xgboost, lightgbm). MLflow is NOT
      in this package set — it ships as the service module
      (services.kailash.mlflow). Nothing installs until enabled (§4.5
      opt-in by default)
    '';

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = o-01-packages;
      defaultText = lib.literalExpression "o-01-generated ++ bespoke overlay rows — modules/ops/generated (manifest-driven)";
      description = ''
        The O-1 category install set: generated from the pinned manifest
        (§4.5 — the manifest is the only hand-maintained registry); native
        rows resolve on the pinned nixpkgs, bespoke rows through the
        packages overlay. Hosts append; never redefine.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = cfg.packages;
  };
}
