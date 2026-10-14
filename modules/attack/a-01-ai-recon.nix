# Layer ATTACK — A-1 AI Recon (KA-13.1, ko#103; spec §3.5, §3.3).
#
# The §4.5 category module for the ATTACK layer's first flagged
# category — the same mount the exemplar
# modules/classic/c-01-information-gathering.nix defines: spine-owned
# typed surface (modules/base/layer-tree.nix declares enable + packages
# at kailash.layers.attack.categories.a-01), config-only install-set
# mount, `mkIf enable` installs (opt-in by default — nothing on PATH
# until the category switch is ON).
#
# SAFETY (§11.2 posture; os#210 purge update 2026-10-14): four of the
# five pre-purge A-1 rows claimed kailash-os upstream repos that were
# never created — the os#210 audit removed them as phantom rows; the
# aspirational names live in the registry (kailash-os#210) and return
# via the rebuild contract (real upstream, manifest gate, ledger).
# The category keeps ONE real row:
#   trufflehog → "safe" (the secret scanner; NATIVE, binds the top-level
#     nixpkgs attr; its SECONDARY is c-08-exploitation-post-exploitation
#     — the a-01 primary owns this install, §4.5 no-duplicate-install
#     rule).
#
# The garak VM proof (`garak --list-probes` in the VM) is KA-13.2's
# wave (ko#104) — this item stays eval-surface (the VM smoke is not
# an a-01/a-02 module deliverable).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-01;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-01-ai-recon.installable;

  # Bare guard uniformity: trufflehog binds bare (the top-level nixpkgs
  # attr IS the id); post-purge the ledger's installable holds only
  # trufflehog.
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (exactly trufflehog at this pin:
    # the other four rows were phantom-upstream, removed per os#210).
    kailash.layers.attack.categories.a-01.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
