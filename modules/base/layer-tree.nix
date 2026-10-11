# The flat layers option tree (KA-17.1, os#114; plan §4.5 transitional).
#
# The §4.5 category module contract grows a per-category option tree —
# `kailash.layers.<layer>.categories.<id>.enable` with manifest-driven
# package lists. The category modules land with Wave-5 module wiring; until
# then the tree is the FLAT spine this module declares:
#
#   kailash.layers.<layer>.enable          — layer-level switch
#   kailash.layers.<layer>.categories      — freeform attrset placeholder
#
# so profiles (redteam-ai today) compose NOW and the per-category modules
# attach to the same path later without a contract change. Categories are
# freeform (attrs of anything) so early per-category settings evaluate
# instead of dying; the Wave-5 modules replace the placeholder with typed
# options.
{ lib, ... }:

let
  layerNames = [ "classic" "attack" "defence" "ops" ];
in
{
  options.kailash.layers = lib.genAttrs layerNames (layer: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Layer ${lib.toUpper layer} tooling on this host. The flat
        spine of the §4.5 option tree — per-category modules (Wave-5
        wiring) attach under categories.<id> on the same path.
      '';
    };
    categories = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Per-category settings placeholder (freeform until the Wave-5 module
        wiring lands typed per-category options on this path).
      '';
    };
  });

  config = { };
}
