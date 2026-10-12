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
# Ledger provenance (the modules' own comments, KA-06.1/06.2):
#   c-01: 38 manifest ids; sublist3r + spiderfoot overlay-pending
#         (bare-guard drops) → 36 PATH rows;
#   c-02: 7 rows; gvm module-status (the KA-27 service module, never a
#         loose tool) + legion overlay-pending → 5 PATH rows;
#   c-04: 7 rows; mssql-cli overlay-pending → 6 PATH rows (psql +
#         redis-cli ride the postgresql_16/redis server packages);
#   c-06: 26 ids; angr build-gap, qiling broken, 7 overlay-pending;
#         cstool+capstone dedupe to one derivation (both PATH names
#         ride it) → 16 derivations, 17 PATH rows.
#
# pathNameForPname (the eval contract's id-compiler): manifest id →
# the derivation NAME the module's binding table maps it to
# (probed-at-pin rows copied from the modules' tables — the contract
# REDs if a binding moves). Returns the manifest id when the module
# binds the package bare (derivation name == id).
{ lib }:
let
  manifest = builtins.fromJSON (builtins.readFile ../generated/manifest-ids.json);
  minus = ids: drops: lib.filter (id: !(lib.elem id drops)) ids;

  pathNameForPname = {
    # c-01: everything binds bare except the two derivation-name
    # mismatches (probed at the c-01 module's pins):
    #   the-harvester → derivation name `theharvester` (no hyphen);
    #   maltego-community → derivation name `maltego` (pkgs.maltego).
    "theharvester" = [ "the-harvester" ];
    "maltego" = [ "maltego-community" ];
    # c-04: the module's named rows ride server packages with
    # derivation names that are NOT the manifest ids.
    "postgresql_16" = [ "psql" ];
    "postgresql" = [ "psql" ];
    "redis" = [ "redis-cli" ];
    # c-02: searchsploit ships inside the exploitdb package.
    "exploitdb" = [ "searchsploit" ];
    # c-06: the module's named rows.
    "capstone" = [ "capstone" "cstool" ];  # cstool rides capstone (the dedupe)
    "edb" = [ "edb-debugger" ];
  };
in
{
  inherit minus pathNameForPname;

  pathNames = {
    c-01 = minus manifest.categories.c-01-information-gathering.installable [
      "sublist3r"
      "spiderfoot"
    ];
    c-02 = minus manifest.categories.c-02-vulnerability-analysis.installable [
      "gvm"
      "legion"
    ];
    c-04 = minus manifest.categories.c-04-database-assessment.installable [
      "mssql-cli"
    ];
    c-06 = minus manifest.categories.c-06-reverse-engineering.installable [
      "angr"
      "qiling"
      "pwndbg"
      "peda"
      "javasnoop"
      "jd-gui"
      "smali"
      "unipacker"
      "pyinstaller-extractor"
    ];
  };

  # Manifest id → the binary name the package actually ships
  # (mismatches only; the rest bind id == binary name).
  binAliases = {
    c-01."the-harvester" = "theHarvester";
    c-06."ghidra" = "ghidraRun";
    c-06."edb-debugger" = "edb";
  };

  # --help-skip rows, each a ONE-LINE reviewable reason. Semantics
  # (tests/vm-smoke-common.nix): an exceptions row excuses BOTH the
  # resolution assertion (unresolved → logged skip, never a failure)
  # and the --help probe (resolved → logged skip).
  helpExceptions = {
    c-02."legion" = "overlay-pending at this pin (bare-guard drop; row returns with the kailash-packages derivation)";
    c-04."mssql-cli" = "overlay-pending at this pin (bare-guard drop; row returns with the kailash-packages derivation)";
    c-06."ghidra" = "GUI launcher (ghidraRun needs a display); store-path resolution still asserted";
    c-06."cutter" = "GUI launcher (needs a display)";
    c-06."iaito" = "GUI launcher (needs a display)";
    c-06."bytecode-viewer" = "GUI jar distribution (bin layout may be the bare .jar)";
    c-06."unicorn" = "library row (the unicorn engine) — no CLI binary ships";
    c-06."gef" = "gdbinit-script row — non-uniform entry point";
    c-06."dex2jar" = "script-suite layout (d2j-* wrappers) — non-uniform entry point";
  };

  flagshipCmds = {
    c-01 = [ "nmap" ];
    c-02 = [ "nikto" ];
    c-04 = [ "sqlmap" ];
    c-06 = [ "ghidra" "radare2" "gdb" "binwalk" ];
  };
}
