# Layer CLASSIC — C-6 Reverse Engineering (KA-06.2, ko#97; plan §4.5).
#
# The second-four category module off the KA-06.1 exemplar (same shape —
# spine-owned typed surface, config-only install mount, mkIf enable).
#
# Binding table (probed at nixpkgs 8c3ced + packages pin 7374e7a — never
# assumed id==attr):
#   * cstool → pkgs.capstone (cstool ships inside the capstone package);
#   * angr, qiling → pkgs.python3Packages.<id> (python-module attrs at
#     this pin — no top-level attrs);
#   * edb-debugger → pkgs.edb (the nixpkgs attr name);
#   * bespoke rows through the packages overlay (peda, javasnoop,
#     jd-gui, unipacker, pyinstaller-extractor at this pin);
#   * pwndbg, smali → NOT at this pin (no nixpkgs attr, no overlay row
#     yet): they drop through the bare guard and return when their
#     derivation lanes land (the exemplar's guard rule);
#   * qiling → marked broken at this pin (python3Packages.qiling, meta
#     broken): the module filters broken-marked rows (the allowInsecure
#     posture covers `insecure`, never a known-broken derivation) and
#     the row returns when nixpkgs fixes the mark.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-06;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-06-reverse-engineering.installable;

  attrFor = id:
    {
      "cstool" = pkgs.capstone or null;
      "angr" = pkgs.python3Packages.angr or null;
      "qiling" = pkgs.python3Packages.qiling or null;
      "edb-debugger" = pkgs.edb or null;
    }."${id}" or (pkgs."${id}" or null);

  # Bind → drop the null (missing-at-pin) AND the broken-marked rows
  # (qiling at this pin); dedupe (cstool + capstone bind the SAME
  # capstone derivation — one primary slot, one install).
  installSet = lib.unique
    (lib.filter (p: p != null && !(p.meta.broken or false)) (map attrFor ids));
in
{
  config = {
    # The manifest-driven install set (24 of the 26 rows at this pin;
    # pwndbg + smali are bespoke-pending — the named drops).
    kailash.layers.classic.categories.c-06.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
