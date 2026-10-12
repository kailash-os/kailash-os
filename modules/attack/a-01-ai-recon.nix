# Layer ATTACK — A-1 AI Recon (KA-13.1, ko#103; plan §4.5, §3.3).
#
# The §4.5 category module for the ATTACK layer's first flagged
# category — the same mount the exemplar
# modules/classic/c-01-information-gathering.nix defines: spine-owned
# typed surface (modules/base/layer-tree.nix declares enable + packages
# at kailash.layers.attack.categories.a-01), config-only install-set
# mount, `mkIf enable` installs (opt-in by default — nothing on PATH
# until the category switch is ON).
#
# SAFETY (§11.2 posture, recorded per row from the manifest at the
# packages pin 7374e7a — the header is the module-level record; the
# manifest is the single home of the facts):
#   recon-ai, llm-recon, colab-crawler → safety.level "requires-target"
#     (target-required ATTACK rows: package-list surfaces, NOT exp-gated
#     — only `safety.level == "exp"` rows ride the lab-mode gate; these
#     target a scope the operator names at run time);
#   huggingface-org-scan → "safe" (public org-surface enumeration);
#   trufflehog → "safe" (the secret scanner; its SECONDARY is
#     c-08-exploitation-post-exploitation — the a-01 primary owns this
#     one install, §4.5 no-duplicate-install rule).
#
# Binding table (probed at nixpkgs 8c3ced + packages pin 7374e7a — never
# assumed id==attr): trufflehog binds top-level nixpkgs (a NATIVE
# manifest row, trufflehog 3.99.0); recon-ai, llm-recon,
# huggingface-org-scan, colab-crawler are manifest-BESPOKE rows whose
# kailash-packages derivations have NOT landed at this pin — they fall
# to the bare guard, resolve null and DROP (named, per-row, in the
# install-set comment below) without breaking eval. Each row returns
# when its derivation lane lands in kailash-packages pkgs/ — the
# exemplar's overlay-pending rule, unchanged shape.
#
# The garak VM proof (`garak --list-probes` in the VM) is KA-13.2's
# wave (ko#104) — this item stays eval-surface (the VM smoke is not
# an a-01/a-02 module deliverable).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-01;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-01-ai-recon.installable;

  # No non-bare bindings at this pin: trufflehog binds bare (the top-level
  # nixpkgs attr IS the id); the four bespoke rows keep the bare guard
  # (their overlay derivations are pending — the named drops resolve null
  # here and return when the lanes land).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (1 of the 5 rows at this pin:
    # trufflehog native; recon-ai, llm-recon, huggingface-org-scan,
    # colab-crawler are overlay-pending bespoke drops — named per the
    # binding table above).
    kailash.layers.attack.categories.a-01.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
