# Layer ATTACK — A-4 Model supply chain (KA-22, kailash-os#22; plan
# §4.5, §9 Phase 5). The §4.5 category module — the same config-only
# mount as the a-01/a-02 exemplars: spine-owned typed surface (enable +
# packages live on kailash.layers.attack.categories.a-04, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default — nothing on PATH until the category switch is ON).
#
# SAFETY (§11.2 posture, read from the generator's ledger — the manifest
# is the single home of the facts; KA-22 extended gen-categories.py to
# carry the exp ledger):
#   * torch-load-poc is the lone exp row — it rides the ledger's `exp`
#     key, NEVER `installable`, never a package-list surface (the §11.2
#     double-key gate owns exp routing);
#   * no data row in this category (the ledger's `excluded` is empty);
#   * the seven installable rows are package-list surfaces.
#
# BINDING TABLE (probed at nixpkgs 8c3ced + packages pin ef70ec4 — never
# assumed id==attr): modelscan is the category's NATIVE row — it binds
# the bare top-level nixpkgs attr at this pin (modelscan 0.8.8, probed
# via the sentinel eval; NOT a python3Packages attr). guarddog,
# picklescan, gguf-template-inspector, safetensors-checker,
# hf-repo-inspector, namespace-reuse-check are manifest-BESPOKE rows
# whose kailash-packages derivations have NOT landed at this pin — they
# fall to the bare guard, resolve null and DROP (named above) without
# breaking eval; guarddog + picklescan return with their derivation
# lane (the kailash-packages pkgs/guarddog pkgs/picklescan dirs), the
# 404-upstream probe rows keep the derivation-free record (the
# kailash-os#22 lane notes on BOTH repos).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-04;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-04-model-supply-chain;

  # No non-bare bindings at this pin: the six pending bespoke rows keep
  # the bare guard; modelscan resolves bare (id == pinned-nixpkgs attr).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (1 of the 7 rows at this pin:
    # modelscan native; guarddog + picklescan return with their
    # derivation lane; the four 404-upstream probe rows stay
    # derivation-free).
    kailash.layers.attack.categories.a-04.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
