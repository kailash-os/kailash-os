# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category o-02-compute-serving-infrastructure
# from the pinned packages manifest; the committed lists are
# drift-checked every PR by the OS flake's category checks.
#
# Excluded at this pin (status → owner — never list entries):
#   module   → the row's own service module: ray, triton-inference-server
#
# PURE DATA on purpose: `native` carries pkgs attr PATHS —
# the category module's resolver ?-guards every path (green
# eval at revisions without the overlay or where a native attr
# moves); `bespoke` carries the packages-overlay rows.
{ ... }:

{
  o-02-compute-serving-infrastructure = {
    native = [
      [ "k3s" ]
      [ "kind" ]
      [ "minikube" ]
      [ "nvidia-container-toolkit" ]
      [ "podman" ]
      [ "vllm" ]
    ];
    bespoke = [
      { id = "kserve"; derivation = "pkgs/kserve/default.nix"; }
      { id = "tgi"; derivation = "pkgs/tgi/default.nix"; }
      { id = "torchserve"; derivation = "pkgs/torchserve/default.nix"; }
    ];
  };
}
