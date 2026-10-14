# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category a-08-data-poisoning
# from the pinned packages manifest; the committed lists are
# drift-checked every PR by the OS flake's category checks.
#
# Excluded at this pin (status → owner — never list entries):
#   (none)
#
# PURE DATA on purpose: `native` carries pkgs attr PATHS —
# the category module's resolver ?-guards every path (green
# eval at revisions without the overlay or where a native attr
# moves); `bespoke` carries the packages-overlay rows.
{ ... }:

{
  a-08-data-poisoning = {
    native = [
    ];
    bespoke = [
      { id = "trojai-toolkit"; derivation = "pkgs/trojai-toolkit/default.nix"; }
    ];
  };
}
