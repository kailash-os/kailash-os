# The flat layers option tree (KA-17.1, os#114; plan §4.5) — the typed
# spine the §4.5 category modules mount at (KA-08.x wave-6).
#
# The load-bearing lib fact (eval-probed at this pin, twice): typed
# per-category options CANNOT declare at
# `kailash.layers.<layer>.categories.<id>` when `categories` is ANY
# attrs-of-(submodule|anything) option — attrs types do not support
# nested options, regardless of submoduleWith/freeformType members. The
# shape that DOES evaluate the whole §4.5 contract:
#
#   * the LAYER option is a submoduleWith with a freeformType member —
#     its typed member is the layer-level `enable`; `categories` is
#     UNDECLARED and lands in the freeform remainder, so
#   * category modules declare their typed options at the FULL path
#     `kailash.layers.<layer>.categories.<id>.<member>` — those
#     declarations evaluate (no attrs-typed middle segment), and
#   * profiles still compose freeform entries
#     (`kailash.layers.ops.categories.o-04.enable = true`) and read them
#     back (redteam-ai's composition, KA-17.1) — the freeform member
#     carries entries whose typed module has not landed.
#
#   kailash.layers.<layer>.enable          — typed, default false
#   kailash.layers.<layer>.categories.<id>.enable|packages — typed per
#     category module (KA-08.x/09.x), default false / [ ]
#   kailash.layers.<layer>.categories.<anything-else> — freeform remainder
{ lib, ... }:

let
  layerNames = [
    "classic"
    "attack"
    "defence"
    "ops"
  ];

  layerType = lib.types.submoduleWith {
    modules = [
      {
        options.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable this layer's tooling on this host (the layer-level
            switch, KA-17.1). Per-category modules land typed at
            layers.<layer>.categories.<id> (the §4.5 contract).
          '';
        };
      }
      # The freeform remainder: `categories` (and anything else under the
      # layer) stays untyped HERE, so full-path per-category declarations
      # from the category modules evaluate (an attrs-typed `categories`
      # member would refuse nested options — the watched RED this spine
      # shape replaced, KA-08.1; profiles compose freeform entries ahead
      # of their typed modules).
      {
        _module.freeformType = lib.types.attrsOf lib.types.anything;
      }
    ];
  };
in

{
  options.kailash.layers = lib.genAttrs layerNames (layer: lib.mkOption {
    type = layerType;
    default = { };
    description = ''
      Layer ${lib.toUpper layer}: enable + the §4.5 per-category tree.
    '';
  });

  config = { };
}
