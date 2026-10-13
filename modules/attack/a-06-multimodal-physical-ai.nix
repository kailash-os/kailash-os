# Layer ATTACK — A-6 Multi-modal & Physical-AI Attacks (KA-23,
# kailash-os#23; plan §4.5, §9 Phase 5). The §4.5 category module — the
# same config-only mount as the a-03/a-04 exemplars: spine-owned typed
# surface (enable + packages live on
# kailash.layers.attack.categories.a-06, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default — nothing on PATH until the category switch is ON).
#
# SAFETY (§11.2 posture, read from the generator's ledger — the manifest
# is the single home of the facts; KA-22 extended gen-categories.py to
# carry the exp ledger):
#   * adversarial-clothing and audio-voice-clone-injector are the two
#     exp rows — they ride the ledger's `exp` key, NEVER `installable`,
#     never a package-list surface (the §11.2 double-key gate owns exp
#     routing; expected-exp-ids.txt carries them);
#   * adversarial-patches-collection is the status:data row (ledger
#     `excluded`, D7 — opt-in data-pack, never installed by category
#     modules);
#   * the two installable rows are package-list surfaces.
#
# BINDING TABLE (probed at nixpkgs 8c3ced + packages pin a3cf74e — never
# assumed id==attr): both installable rows are manifest-BESPOKE whose
# kailash-packages derivations have NOT landed at this pin (no
# pkgs/vlm-image-injector, pkgs/camera-adversarial-toolkit dirs at a3cf74e)
# — they fall to the bare guard, resolve null and DROP (named above)
# without breaking eval; the empty install set is CORRECT at this pin
# (the honest-pending posture a-03/a-04 record) and each row returns
# when its derivation lane lands in kailash-packages pkgs/.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-06;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-06-multimodal-physical-ai;

  # No non-bare bindings at this pin: both installable rows keep the
  # bare guard (the overlay attrs are the ids per §5.5 auto-call — the
  # named drops resolve null here and return with their lanes).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (EMPTY at this pin: both
    # installable rows are derivation-pending bespoke rows; the exp
    # rows stay off this surface entirely).
    kailash.layers.attack.categories.a-06.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
