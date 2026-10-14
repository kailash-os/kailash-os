# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category a-05-model-extraction-inversion
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
  a-05-model-extraction-inversion = {
    native = [
    ];
    bespoke = [
      { id = "art"; derivation = "pkgs/art/default.nix"; }
      { id = "cleverhans"; derivation = "pkgs/cleverhans/default.nix"; }
      { id = "counterfit"; derivation = "pkgs/counterfit/default.nix"; }
      { id = "foolbox"; derivation = "pkgs/foolbox/default.nix"; }
      { id = "knockoffnets"; derivation = "pkgs/knockoffnets/default.nix"; }
      { id = "privacy-meter"; derivation = "pkgs/privacy-meter/default.nix"; }
      { id = "tf-privacy"; derivation = "pkgs/tf-privacy/default.nix"; }
    ];
  };
}
