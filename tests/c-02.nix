# VM smoke test — C-2 Vulnerability Analysis (KA-06.3, ko#98; spec §8 Phase 2).
#
# The booted-VM acceptance leg for the c-02 category module
# (modules/classic/c-02-vulnerability-analysis.nix): kailash-full
# boots, the manifest-driven c-02 install surface is in the VM
# closure, and every non-deferred manifest PATH row resolves and
# answers `--help` with exit 0.
#
# Ledger (tests/vm-smoke-tables.nix): gvm is module-status (the KA-27
# service module — never a loose tool, excluded like the module does);
# legion is overlay-pending (the --help-exempt row until the
# derivation lands); searchsploit rides the exploitdb package.
#
# Executed on a Linux VM host:  nix build -L .#vmTests.x86_64-linux.c-02
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
  categoryName = "c-02";
  title = "vm-smoke-c-02";
  categories = [ "c-02" ];
  installSurface = { c-02 = installSurface; };
  pathNames = { c-02 = tables.pathNames.c-02; };
  binAliases = { c-02 = tables.binAliases.c-02 or { }; };
  helpExceptions = { c-02 = tables.helpExceptions.c-02 or { }; };
  flagshipCmds = { c-02 = tables.flagshipCmds.c-02; };
}
