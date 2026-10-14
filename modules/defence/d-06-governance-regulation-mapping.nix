# Layer DEFENCE — D-6 AI Governance & Regulation Mapping (KA-24, os#24;
# spec §3.5, §9 Phase 6). The §4.5 category module — config-only mount
# on the typed spine (enable + packages at
# kailash.layers.defence.categories.d-06), the KA-13.1 exemplar shape.
#
# Binding table (os#210 purge, 2026-10-14): every pre-purge d-06 row
# (a governance template pack family) was phantom-origin — no real
# upstream anywhere; removed by the audit; names in the registry
# (kailash-os#210). The category is EMPTY post-purge: the install mount
# stays wired for the rebuild contract (a real governance pack returns
# with a verified upstream through the manifest gate).
#
# SAFETY: every d-06 row is safety.level "safe" at this revision.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-06;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-06-governance-regulation-mapping.installable;

  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (EMPTY post-os#210: every d-06
    # row was phantom-origin, removed).
    kailash.layers.defence.categories.d-06.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
