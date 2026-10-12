# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category o-01-mlops-ml-engineering
# from the pinned packages manifest; the committed lists are
# drift-checked every PR by the OS flake's category checks.
#
# Excluded at this pin (status → owner — never list entries):
#   module   → the row's own service module: airflow, clearml, mlflow, prefect
#
# PURE DATA on purpose: `native` carries pkgs attr PATHS —
# the category module's resolver ?-guards every path (green
# eval at revisions without the overlay or where a native attr
# moves); `bespoke` carries the packages-overlay rows.
{ ... }:

{
  o-01-mlops-ml-engineering = {
    native = [
      [ "dvc" ]
      [ "git-lfs" ]
      [ "lightgbm" ]
      [ "python3Packages" "numpy" ]
      [ "python3Packages" "pandas" ]
      [ "python3Packages" "polars" ]
      [ "python3Packages" "scikit-learn" ]
      [ "python3Packages" "scipy" ]
      [ "python3Packages" "wandb" ]
      [ "xgboost" ]
    ];
    bespoke = [
      { id = "bentoml"; derivation = "pkgs/bentoml/default.nix"; }
      { id = "feast"; derivation = "pkgs/feast/default.nix"; }
      { id = "kedro"; derivation = "pkgs/kedro/default.nix"; }
      { id = "kedro-datasets"; derivation = "pkgs/kedro-datasets/default.nix"; }
    ];
  };
}
