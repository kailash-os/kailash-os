# Layer ATTACK — A-4 Model supply chain (KA-22, kailash-os#22; plan
# §4.5, §9 Phase 5). The §4.5 category module — the same config-only
# mount as the a-01/a-02 exemplars: spine-owned typed surface (enable +
# packages live on kailash.layers.attack.categories.a-04, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default — nothing on PATH until the category switch is ON).
#
# SAFETY (§11.2 posture; os#210 purge update 2026-10-14): the exp row
# (torch-load-poc) and the four supply-chain inspector rows
# (gguf-template-inspector, safetensors-checker, hf-repo-inspector,
# namespace-reuse-check) were phantom-upstream — claimed kailash-os
# repos never created, removed by the os#210 audit; the aspirational
# names live in the registry (kailash-os#210). The three real rows:
#   * guarddog, picklescan — bespoke, derivations LANDED in
#     kailash-packages pkgs/ (the KA-22 lanes);
#   * modelscan — NATIVE (upstream protectai/modelscan; binds the bare
#     top-level nixpkgs attr, modelscan 0.8.8 probed 2026-10-14 per the
#     os#210 gate receipt — NOT a python3Packages attr).
# No data row in this category; the three installable rows are
# package-list surfaces.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-04;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-04-model-supply-chain;

  # Binding: guarddog/picklescan bind their landed overlay derivations;
  # modelscan resolves bare (id == pinned-nixpkgs attr).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (all three real rows bind after
    # the KA-22 derivation lanes: guarddog + picklescan overlay,
    # modelscan native; the four inspector rows + torch-load-poc were
    # phantom-upstream, removed per os#210).
    kailash.layers.attack.categories.a-04.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
