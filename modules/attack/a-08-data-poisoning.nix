# Layer ATTACK — A-8 Data Poisoning (KA-23, kailash-os#23; plan §4.5,
# §9 Phase 5). The §4.5 category module — the same config-only mount as
# the a-03/a-04 exemplars: spine-owned typed surface (enable +
# packages live on kailash.layers.attack.categories.a-08, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default — nothing on PATH until the category switch is ON).
#
# SAFETY (§11.2 posture, read from the generator's ledger — the manifest
# is the single home of the facts; KA-22 extended gen-categories.py to
# carry the exp ledger):
#   * poison-dataset-builder, trojan-lm-toolkit, prompt-backdoor-tool
#     and data-exfil-via-poison are the four exp rows — they ride the
#     ledger's `exp` key, NEVER `installable`, never a package-list
#     surface (the §11.2 double-key gate owns exp routing;
#     expected-exp-ids.txt carries them);
#   * no data row in this category (the ledger's `excluded` is empty);
#   * the two installable rows are package-list surfaces.
#
# BINDING TABLE (probed at nixpkgs 8c3ced + packages pin a3cf74e — never
# assumed id==attr): both installable rows are manifest-BESPOKE whose
# kailash-packages derivations have NOT landed at this pin (no
# pkgs/trojai-toolkit, pkgs/split-view-replay dirs at a3cf74e — the
# binding-table comment in a-03 names only the then-landed rows; this
# pin's trojai row binds the trojai/trojai upstream) — they fall to the
# bare guard, resolve null and DROP (named above) without breaking
# eval; the empty install set is CORRECT at this pin (the
# honest-pending posture a-03/a-04 record) and each row returns when
# its derivation lane lands in kailash-packages pkgs/.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-08;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-08-data-poisoning;

  # No non-bare bindings at this pin: both installable rows keep the
  # bare guard (the overlay attrs are the ids per §5.5 auto-call — the
  # named drops resolve null here and return with their lanes).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);

  require = cond: msg: if cond then true else throw msg;
  _evalProofs = [
    (require (ledger.exp == [
      "poison-dataset-builder"
      "trojan-lm-toolkit"
      "prompt-backdoor-tool"
      "data-exfil-via-poison"
    ])
      "a-08-options: the generator's exp ledger does not record exactly the four A-8 poisoning-exploit rows (KA-23 GREEN)")
    (require (!(lib.elem "poison-dataset-builder" ledger.installable)
      && !(lib.elem "trojan-lm-toolkit" ledger.installable)
      && !(lib.elem "prompt-backdoor-tool" ledger.installable)
      && !(lib.elem "data-exfil-via-poison" ledger.installable))
      "a-08-options: an exp row rides the a-08 installable ledger (KA-23)")
  ];
in
{
  config = {
    # The manifest-driven install set (EMPTY at this pin: the two
    # installable rows are derivation-pending bespoke rows; the four
    # exp rows stay off this surface entirely).
    kailash.layers.attack.categories.a-08.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
