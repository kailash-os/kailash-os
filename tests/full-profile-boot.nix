# VM smoke test — full-profile boot (KA-06.3, ko#98; spec §8 Phase 2).
#
# The kailash-full PROFILE's booted acceptance leg: the CORE floor +
# the four shipped CLASSIC categories in one boot; the per-category
# sweeps (the same four assertion phases the category legs run, over
# the SHARED tables — tests/vm-smoke-tables.nix) PLUS the per-category
# flagship anchors — the issue's `which nmap` form, resolved against
# the composed VM PATH.
#
# Executed on a Linux VM host:
#   nix build -L .#vmTests.x86_64-linux.full-profile-boot
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
  categoryName = "full-profile";
  title = "vm-smoke-full-profile-boot";
  categories = [
    "c-01"
    "c-02"
    "c-04"
    "c-06"
  ];
  installSurface = {
    c-01 = installSurface.c-01;
    c-02 = installSurface.c-02;
    c-04 = installSurface.c-04;
    c-06 = installSurface.c-06;
  };
  pathNames = tables.pathNames;
  binAliases = tables.binAliases;
  helpExceptions = tables.helpExceptions;
  flagshipCmds = tables.flagshipCmds;
}
