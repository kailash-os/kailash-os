# VM smoke test — C-6 Reverse Engineering (KA-06.3, ko#98; plan §9 Phase 2).
#
# The booted-VM acceptance leg for the c-06 category module
# (modules/classic/c-06-reverse-engineering.nix): kailash-full boots,
# the 16-derivation manifest-driven c-06 install surface is in the VM
# closure, and every resolvable manifest PATH row answers `--help`
# with exit 0.
#
# Ledger (tests/vm-smoke-tables.nix): 26 manifest ids → 17 PATH rows →
# 16 install derivations (cstool+capstone dedupe to one derivation,
# both PATH names ride it); angr build-gap drop + qiling broken-marked
# drop + 7 overlay-pending rows ride the module's bare guard and this
# suite's drops table; GUI launchers (ghidra → ghidraRun, cutter,
# iaito), the bare-jar row (bytecode-viewer), the library row
# (unicorn) and the non-uniform entry points (gef, dex2jar) ride
# --help-exempt rows — with store-path resolution still asserted.
#
# Executed on a Linux VM host:  nix build -L .#vmTests.x86_64-linux.c-06
# (see tests/README.md; hosted CI evals this file, never boots it).
{
  lib,
  pkgs,
  system,
  installSurface,
}:
let
  tables = import ./vm-smoke-tables.nix { inherit lib; };
in
import ./vm-smoke-common.nix {
  inherit lib pkgs system;
  categoryName = "c-06";
  title = "vm-smoke-c-06";
  categories = [ "c-06" ];
  installSurface = { c-06 = installSurface; };
  pathNames = { c-06 = tables.pathNames.c-06; };
  binAliases = { c-06 = tables.binAliases.c-06 or { }; };
  helpExceptions = { c-06 = tables.helpExceptions.c-06 or { }; };
  flagshipCmds = { c-06 = tables.flagshipCmds.c-06; };
}
