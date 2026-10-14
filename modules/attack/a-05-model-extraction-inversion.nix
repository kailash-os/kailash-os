# Layer ATTACK — A-5 Model Extraction, Inversion & MIA (KA-23,
# kailash-os#23; spec §3.5, §9 Phase 5). The §4.5 category module — the
# same config-only mount as the a-03/a-04 exemplars: spine-owned typed
# surface (enable + packages live on
# kailash.layers.attack.categories.a-05, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default — nothing on PATH until the category switch is ON).
#
# SAFETY (§11.2 posture, read from the generator's ledger — the manifest
# is the single home of the facts): no exp rows and no data rows in this
# category (the ledger's `exp` key is absent, `excluded` is empty); all
# eight rows are package-list surfaces.
#
# BINDING TABLE (probed at nixpkgs 8c3ced + packages pin a3cf74e — never
# assumed id==attr): all eight rows are manifest-BESPOKE (status
# bespoke, derivation pkgs/<id>/default.nix). At this pin TWO have
# landed in kailash-packages pkgs/ and bind through the composed
# overlay: art 1.20.1 (pkgs/art, KA-12.1) and counterfit 1.1.0
# (pkgs/counterfit, KA-12.2). The SIX derivation-pending rows —
# foolbox, cleverhans, knockoffnets, model-extraction-attack,
# tf-privacy, privacy-meter — fall to the bare guard, resolve null and
# DROP (named above) without breaking eval — the same honest-pending
# posture a-03 and a-04 record: `foolbox` and `cleverhans` are the
# plan's "week-after" rows (the manifest tags say so on the row), and
# tf-privacy/privacy-meter/knockoffnets/model-extraction-attack bind
# upstream python sources (tensorflow/privacy, privacytrustlab/
# ml_privacy_meter — note the manifest's `privacy-meter` id maps the
# ml_privacy_meter repo, not a same-named repo — and
# tribhuvanesh/knockoffnets) whose derivation lanes land after this
# module. Each row returns through the SAME bare guard the moment its
# pkgs/<id> dir lands in kailash-packages and the lock rides forward;
# the a-05-ledger legs (a-05-options) own the count proof every PR.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-05;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-05-model-extraction-inversion;

  # No non-bare bindings at this pin: all eight rows keep the bare
  # guard (the overlay attrs are the ids per §5.5 auto-call; the
  # derivation-pending drops resolve null here and return with their
  # lanes). Resolved set at the current lock: art, counterfit.
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (2 of the 8 rows bind at this pin —
    # art + counterfit via the overlay; six derivation-pending drops,
    # named above, return with their lanes).
    kailash.layers.attack.categories.a-05.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
