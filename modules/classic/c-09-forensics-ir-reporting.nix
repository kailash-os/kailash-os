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
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-09;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-09-forensics-ir-reporting.installable;

  # RED stub (KA-07.3, ko#101): the module consumes NOTHING yet — the
  # reviewed binding-table wiring lands in the GREEN commit of this
  # watched red→green pair; the c-09-options leg's non-empty assertion
  # is the watched red ("installs NOTHING").
  installSet = [ ];
in
{
  config = {
    kailash.layers.classic.categories.c-09.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
