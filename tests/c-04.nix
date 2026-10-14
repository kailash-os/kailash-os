# VM smoke test — C-4 Database Assessment (KA-06.3, ko#98; spec §8 Phase 2).
#
# The booted-VM acceptance leg for the c-04 category module
# (modules/classic/c-04-database-assessment.nix): kailash-full boots,
# the manifest-driven c-04 install surface is in the VM closure, and
# every manifest PATH row resolves and answers `--help` with exit 0.
#
# Ledger (tests/vm-smoke-tables.nix): all 7 manifest rows are in the
# module's install set at this pin; psql/redis-cli ride the
# postgresql_16/redis server packages' bin dirs; mssql-cli is
# overlay-pending (the --help-exempt row until the derivation lands).
#
# Executed on a Linux VM host:  nix build -L .#vmTests.x86_64-linux.c-04
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
  categoryName = "c-04";
  title = "vm-smoke-c-04";
  categories = [ "c-04" ];
  installSurface = { c-04 = installSurface; };
  pathNames = { c-04 = tables.pathNames.c-04; };
  binAliases = { c-04 = tables.binAliases.c-04 or { }; };
  helpExceptions = { c-04 = tables.helpExceptions.c-04 or { }; };
  flagshipCmds = { c-04 = tables.flagshipCmds.c-04; };
}
