# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category o-06-documentation-reporting-authoring
# from the pinned packages manifest; the committed lists are
# drift-checked every PR by the OS flake's category checks.
#
# Excluded at this pin (status → owner — never list entries):
#   data     → the kailash-data packs: texlive-full
#   module   → the row's own service module: dradis
#
# PURE DATA on purpose: `native` carries pkgs attr PATHS —
# the category module's resolver ?-guards every path (green
# eval at revisions without the overlay or where a native attr
# moves); `bespoke` carries the packages-overlay rows.
{ ... }:

{
  o-06-documentation-reporting-authoring = {
    native = [
      [ "drawio" ]
      [ "mdbook" ]
      [ "mermaid-cli" ]
      [ "obsidian" ]
      [ "pandoc" ]
      [ "quarto" ]
      [ "typst" ]
    ];
    bespoke = [
      { id = "excalidraw"; derivation = "pkgs/excalidraw/default.nix"; }
    ];
  };
}
