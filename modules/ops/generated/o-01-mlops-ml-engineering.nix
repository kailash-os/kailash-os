# GENERATED FILE — KA-08.1 (ko#105). DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category o-01-mlops-ml-engineering
# from the pinned packages manifest (vended manifest/tools.yaml; the
# committed lists drift-checked every PR by checks.o-01-options).
# Source pin: kailash-packages 7374e7a7650513bdaed11863a2fcb076041a890c.
#
# Selection contract (§4.5; plan §11.2): this category's manifest rows whose
# packaging.status is "native", resolved on the pinned nixpkgs — attr
# divergence (id != attr) recorded per row in NATIVE_ATTRS; module-status
# rows are OWNED BY THEIR SERVICE MODULES (mlflow → services.kailash.mlflow)
# and NEVER reach a package list; bespoke rows resolve through the packages
# overlay and are excluded at revisions without it; safety.level == "exp"
# rows NEVER reach a package list (the §11.2 double-key gate owns exp-class
# routing — no o-01 rows are exp at this pin, the o-02 list carries the
# proof-by-shape).
#
# id → pkgs attr resolution probed at the pin (nix eval, never assumed):
#   dvc                    → pkgs.dvc                       (dvc-3.67.1)
#   git-lfs                → pkgs.git-lfs                   (git-lfs-3.8.0)
#   wandb-cli              → pkgs.python3Packages.wandb     (python3.14-wandb-0.30.0;
#                            the CLI executable ships inside the wandb
#                            python package; no standalone wandb-cli attr)
#   pandas                 → pkgs.python3Packages.pandas    (python3.14-pandas-3.0.4)
#   polars                 → pkgs.python3Packages.polars    (python3.14-polars-1.42.1)
#   scikit-learn           → pkgs.python3Packages.scikit-learn (python3.14-scikit-learn-1.9.0)
#   numpy                  → pkgs.python3Packages.numpy     (python3.14-numpy-2.5.2)
#   scipy                  → pkgs.python3Packages.scipy     (python3.14-scipy-1.18.1)
#   xgboost                → pkgs.xgboost                   (xgboost-3.0.5)
#   lightgbm               → pkgs.lightgbm                  (lightgbm-4.6.0)
# Excluded as module rows (never a package list entry at this pin):
#   mlflow (module → services.kailash.mlflow), clearml, airflow, prefect.
# Excluded as bespoke rows (resolve through the packages overlay):
#   bentoml, feast, kedro, kedro-datasets.
# Guarded resolution (resolvers in the category module): every attr path is
# `?`-guarded so host evaluation stays green at revisions without the
# overlay or at nixpkgs revs where a native attr moves.
{ lib, pkgs }:

{
  o-01-mlops-ml-engineering = [
    pkgs.dvc
    pkgs.git-lfs
    pkgs.python3Packages.wandb
    pkgs.python3Packages.pandas
    pkgs.python3Packages.polars
    pkgs.python3Packages.scikit-learn
    pkgs.python3Packages.numpy
    pkgs.python3Packages.scipy
    pkgs.xgboost
    pkgs.lightgbm
  ];
}
