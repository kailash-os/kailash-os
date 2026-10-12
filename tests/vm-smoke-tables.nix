# VM smoke suite — the per-category PATH-row tables (KA-06.3, ko#98).
#
# The SINGLE HOME of the expected per-category surfaces the VM smoke
# legs assert against: the manifest ids (generated/manifest-ids.json)
# compiled through each module's reviewed binding table + drop ledger
# (the same rows the module files document). Consumed by BOTH the
# vmTests legs (tests/c-01.nix etc. via tests/vm-smoke-common.nix) AND
# the eval contract check (checks.classic-vm-smoke-contract — the
# watched-RED leg binding the suite to the §4.5 module options), so a
# module lane that moves a reviewed row edits HERE once and both the
# boot suite and the watchdog pick it up.
#
# pathNameForPname (the eval contract's id-compiler): manifest id →
# the derivation NAME the module's binding table maps it to
# (probed-at-pin rows copied from the modules' tables — the contract
# REDs if a binding moves). Returns the manifest id when the module
# bonds the package bare (derivation name == id).
#
# RED STUB (KA-06.3, ko#98, the watched red): the tables file ships
# EMPTY — every vmTests PATH table and the contract leg's tables side
# are empty, so the contract leg REDs (`tables != eval-side` per
# category, both sides printed) while the module lanes stay green
# (their own legs read the MODULE options, never the tables). The
# GREEN commit fills the four tables + the pathNameForPname map.
{ lib }:
let
  manifest = builtins.fromJSON (builtins.readFile ../generated/manifest-ids.json);
in
{
  minus = ids: drops: lib.filter (id: !(lib.elem id drops)) ids;

  pathNameForPname = { };

  pathNames = {
    c-01 = [ ];
    c-02 = [ ];
    c-04 = [ ];
    c-06 = [ ];
  };

  # Manifest id → the binary name the package actually ships
  # (mismatches only; the rest bind id == binary name).
  binAliases = {
    c-01 = { };
    c-06 = { };
  };

  # --help-skip rows, each a ONE-LINE reviewable reason. Semantics
  # (tests/vm-smoke-common.nix): an exceptions row excuses BOTH the
  # resolution assertion (unresolved → logged skip, never a failure)
  # and the --help probe (resolved → logged skip).
  helpExceptions = {
    c-02 = { };
    c-04 = { };
    c-06 = { };
  };

  flagshipCmds = { };
}
