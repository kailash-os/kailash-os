# Layer ATTACK — A-6 Multi-modal & Physical-AI Attacks (KA-23,
# kailash-os#23; os#210 purge update 2026-10-14). The category module —
# spine-owned typed surface (enable + packages live on
# kailash.layers.attack.categories.a-06, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default).
#
# POST-PURGE STATE: every A-6 manifest row (adversarial-clothing,
# adversarial-patches-collection, audio-voice-clone-injector,
# camera-adversarial-toolkit, vlm-image-injector) claimed a kailash-os
# upstream repo that was NEVER created — the os#210 audit removed all
# five as phantom rows, so the category is EMPTY (0 primary rows). The
# aspirational names live in the registry
# (kailash-os#210, first comment) and return only through the rebuild
# contract: build the tool, ship a verified upstream, then the manifest
# gate admits the row and this module's install mount picks it up
# unchanged.
#
# BINDING TABLE: none — there is nothing to bind. The install mount
# reads the generator ledger (empty install set by construction) and
# stays wired for when a real row lands; the §11.2 exp-routing record
# for this category rides the same empty ledger.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-06;

  # post-os#210 the ledger is OMITTED when the category empties —
  # default the empty shape (absence IS the empty assertion)
  ledger = ((builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json)).categories)
    .a-06-multimodal-physical-ai or { installable = [ ]; excluded = [ ]; exp = [ ]; };

  # Bare guard (composition uniformity): post-purge the ledger's
  # installable is EMPTY — a non-empty list would mean a row reappeared
  # without going through the rebuild contract, which the packages
  # upstream-realism gate refuses (validate_manifest, os#210).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (EMPTY post-os#210: the category
    # is aspirational-only at this pin).
    kailash.layers.attack.categories.a-06.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
