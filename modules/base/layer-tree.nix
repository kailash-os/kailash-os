# The flat layers option tree (KA-17.1, os#114; spec §3.5).
#
#   kailash.layers.<layer>.enable          — layer-level switch
#   kailash.layers.<layer>.categories.<id> — typed per-category entries
#
# GREEN (KA-09.1): `categories` upgrades from the freeform
# `attrsOf anything` placeholder to TYPED per-category options — one
# option-decl block per category id (mkOption sugar). That is the shape
# the NixOS module tree MERGES on: every category module (KA-08.x,
# KA-09.x wave items) declares the same sugar at its own id and the
# member options merge across modules (mixin options like backends join
# with enable + packages). The old freeform placeholder could not carry
# nested typed options at all — the watched RED this spine replaced.
# (KA-08.1 independently probed the same question and reached the same
# shape: its submodule-with-freeform variant was superseded by this
# per-id declared tree — the two lanes' eval contracts converge here.)
#
# The declared ids are the manifest's §3.6 census (manifest/categories.yaml,
# single home of the id facts — the list mirrors the category ids, never
# invents one); an id typed nowhere and set by a profile fails eval loudly
# (the merge machinery's `does not exist`), which is the honesty posture
# this contract buys: no silent freeform absorption.
#
# The enable switch defaults per layer; packages defaults empty — the
# category install sets ride the §4.5 module config (mkIf installs), so
# the floor here stays a no-op config.
{ lib, ... }:

let
  layerNames = [
    "classic"
    "attack"
    "defence"
    "ops"
  ];

  # The §3.6 category census, per layer, in manifest id order — the typed
  # surface every category module joins. The tree keys categories by the
  # SHORT manifest id (o-04), the form profiles and the flake checks
  # address (flake.nix kailash-redteam-ai-options); the long manifest id
  # (o-04-local-llm-inference-labs) stays the manifest's identity and the
  # module FILE's name — mirror of manifest/categories.yaml ids (KA-05
  # census; a manifest rename lands in both files in one cycle).
  categoryIds = {
    classic = [ "c-01" "c-02" "c-03" "c-04" "c-05" "c-06" "c-07" "c-08" "c-09" "c-10" ];
    attack = [ "a-01" "a-02" "a-03" "a-04" "a-05" "a-06" "a-07" "a-08" ];
    defence = [ "d-01" "d-02" "d-03" "d-04" "d-05" "d-06" "d-07" ];
    ops = [ "o-01" "o-02" "o-03" "o-04" "o-05" "o-06" "o-07" ];
  };

  # One typed entry per id: enable + packages (the §4.5 baseline members
  # every category shares; per-category modules mixin their own members at
  # the same sugar path).
  categoryEntry = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        The §4.5 category switch — the category module's mkIf config
        installs the category surface when this is true.
      '';
    };
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        The category's package list. The §4.5 category-module config
        (mkIf enable) installs it; hosts compose here (append; never
        redefine).
      '';
    };
  };
in

{
  options.kailash.layers = lib.genAttrs layerNames (layer: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Layer ${lib.toUpper layer} tooling on this host. The flat
        spine of the §4.5 option tree — per-category modules attach under
        categories.<id> on the same path.
      '';
    };
    categories = lib.genAttrs categoryIds.${layer} (_: categoryEntry);
  });

  config = { };
}
