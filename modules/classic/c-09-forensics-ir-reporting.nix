# Layer CLASSIC — C-9 Forensics, IR & Reporting (KA-07.3, ko#101; plan
# §4.5).
#
# The §4.5 category module shape off the KA-06.1 exemplar: the typed
# spine (modules/base/layer-tree.nix) owns enable/packages on
# kailash.layers.classic.categories.c-09; this module mounts the
# install set config-only, consuming generated/manifest-ids.json through
# its reviewed binding table; mkIf enable installs (opt-in by default).
#
# The manifest's status:module rows (timesketch, faraday, pwndoc-ng) are
# EXCLUDED from the package-list surface by the generator's ledger —
# they ship as systemd SERVICE modules in a later lane, never as
# package-list rows; this module's binding table therefore never sees
# them and the c-09-options flake leg cross-asserts their absence from
# the install set by construction. The status:data row (sysmon-modular,
# sigma rule packs) is likewise outside the package surface (the D7
# opt-in posture; category modules never install data rows).
#
# Binding table (probed at nixpkgs 8c3ced + packages pin 7374e7a —
# never assumed id==attr):
#   * photorec → pkgs.testdisk (photorec ships inside the testdisk
#     package — the pin's testdisk out/bin carries fidentify,
#     photorec, testdisk); the manifest's separate row DEDUPES to the
#     same derivation;
#   * ewfacquire → pkgs.libewf (the ewf* tool family — ewfacquire,
#     ewfexport, ewfinfo, ewfmount, ewfrecover, ewfverify — ships inside
#     the libewf package; the manifest id is the ewfacquire CLI);
#   * autopsy → pkgs.autopsy (4.23.1; license:free set, no unfree mark);
#   * chkrootkit → REMOVED from nixpkgs at this pin ("unmaintained and
#     archived upstream and didn't even work on NixOS" — the attr
#     THROWS on access, which the bare `or null` guard cannot catch):
#     a named pre-filter drop WITH the run evidence; the row returns
#     through its manifest-bespoke kailash-packages derivation
#     (pkgs/chkrootkit) when that overlay row reaches a shipped pin;
#   * rkhunter, plaso → manifest-bespoke rows whose kailash-packages
#     derivations (pkgs/rkhunter, pkgs/plaso) exist in the authoring
#     tree but are NOT in the shipped package set at this pin (the
#     packages overlay exports only the earlier auto-call rows — the
#     mssql-cli precedent, ko#97): they drop through the bare guard and
#     return when a packages lock-bump ships them;
#   * chainsaw, hayabusa → status:stale rows bound bare: both are
#     clean-at-pin nixpkgs attrs (2.16.5 / 0.3.9, GPL-3.0-only /
#     AGPL-3.0-only) — the manifest's staleness is an
#     upstream-freshness note, not a packaging defect; the
#     kailash-packages nvfetcher lanes refresh their pins.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-09;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-09-forensics-ir-reporting.installable;

  # Named drops WITH reasons (capture-evidenced at this pin):
  # chkrootkit's nixpkgs attr THROWS on access ("removed as it is
  # unmaintained and archived upstream and didn't even work on NixOS")
  # — a throw bypasses `or null`, so the id is dropped before the
  # bind. The bespoke overlay row returns it when a shipped pin
  # carries pkgs/chkrootkit.
  namedDrops = [
    "chkrootkit"
  ];

  attrFor = id:
    {
      "photorec" = pkgs.testdisk or null;
      "ewfacquire" = pkgs.libewf or null;
    }."${id}" or (pkgs."${id}" or null);

  boundIds = lib.filter (id: !(lib.elem id namedDrops)) ids;
  installSet = lib.unique
    (lib.filter
      (p: p != null && !(p.meta.broken or false))
      (map attrFor boundIds));
in
{
  config = {
    # The manifest-driven install set (14 of the 17 installable ids at
    # this pin: photorec→testdisk + ewfacquire→libewf dedupe to their
    # host derivations; chkrootkit named-drop (nixpkgs-removed attr);
    # rkhunter + plaso overlay-pending drops).
    kailash.layers.classic.categories.c-09.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
