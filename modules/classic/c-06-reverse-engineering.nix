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
#   * angr → eval-resolves (python3Packages.angr) but the BUILD fails
#     on x86_64 at this pin ("angr requires setuptools-rust to build" —
#     the nixpkgs packaging's dep gap; hosted flake-check job
#     114623996385): a named drop with the run evidence, the same rule
#     as a broken mark — the row returns when the packaging gains the
#     build dep;
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

  # Named drops WITH reasons (build-evidenced at this pin): angr's
  # nixpkgs packaging lacks setuptools-rust. Same rule as broken-marked:
  # the row returns when the packaging gains the build dep.
  namedDrops = [
    "angr"
  ];

  attrFor = id:
    {
      "cstool" = pkgs.capstone or null;
      "qiling" = pkgs.python3Packages.qiling or null;
      "edb-debugger" = pkgs.edb or null;
    }."${id}" or (pkgs."${id}" or null);

  # Bind → drop the null (missing-at-pin), the named drops (the
  # build-evidenced list above), AND the broken-marked rows (qiling at
  # this pin); dedupe (cstool + capstone bind the SAME capstone
  # derivation — one primary slot, one install).
  boundIds = lib.filter (id: !(lib.elem id namedDrops)) ids;
  installSet = lib.unique
    (lib.filter
      (p: p != null && !(p.meta.broken or false))
      (map attrFor boundIds));
in
{
  config = {
    # The manifest-driven install set (17 of the 26 ids at this pin:
    # 7 overlay-pending drops, angr build-evidenced drop, qiling
    # broken-marked drop, cstool+capstone dedupe to one derivation).
    kailash.layers.classic.categories.c-06.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
