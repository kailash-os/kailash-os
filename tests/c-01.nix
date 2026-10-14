# VM smoke test — C-1 Information Gathering (KA-06.3, ko#98; spec §8 Phase 2).
#
# The booted-VM acceptance leg for the c-01 category module (KA-06.1
# exemplar, modules/classic/c-01-information-gathering.nix):
# kailash-full boots, the manifest-driven c-01 install surface is in
# the VM closure, and every manifest PATH row resolves and answers
# `--help` with exit 0 (per command, ko#98's acceptance).
#
# Truthfulness: the expected surface is the §4.5 module option's
# install set read at flake eval scope (installSurface) and the PATH
# rows are the manifest ids compiled through the reviewed ledger in
# tests/vm-smoke-tables.nix — never asserted from any `kailash list`
# output (the CLI is not a shipped derivation at this pin; comparing
# against it would be circular).
#
# Executed on a Linux VM host:  nix build -L .#vmTests.x86_64-linux.c-01
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
  categoryName = "c-01";
  title = "vm-smoke-c-01";
  categories = [ "c-01" ];
  installSurface = { c-01 = installSurface; };
  pathNames = { c-01 = tables.pathNames.c-01; };
  binAliases = { c-01 = tables.binAliases.c-01 or { }; };
  helpExceptions = { c-01 = tables.helpExceptions.c-01 or { }; };
  flagshipCmds = { c-01 = tables.flagshipCmds.c-01; };
}
