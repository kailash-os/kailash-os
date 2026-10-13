# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category a-08-data-poisoning
# from the pinned packages manifest; the committed lists are
# drift-checked every PR by the OS flake's category checks.
#
# No emit exists for this category BY CONSTRUCTION: a-08's rows are 4
# safety:exp + 2 derivation-pending bespoke — the generator REFUSES an
# exp-carrying category's package-list emit (plan §11.2: the double-key
# gate owns exp routing; the refusal IS the contract, exit 1 + the
# named row list on stderr). The category module consumes
# generated/manifest-ids.json directly (bare guard); the a-08 drift
# leg pins the REFUSAL (regen the a-05 file instead — the one
# exp-free long-tail emit) + the ledger shape.
{ ... }:

{
  a-08-data-poisoning = {
    native = [ ];
    bespoke = [
      { id = "split-view-replay"; derivation = "pkgs/split-view-replay/default.nix"; }
      { id = "trojai-toolkit"; derivation = "pkgs/trojai-toolkit/default.nix"; }
    ];
  };
}
