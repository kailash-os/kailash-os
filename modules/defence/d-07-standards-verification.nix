# Layer DEFENCE — D-7 Standards Verification Toolkit (KA-24, os#24;
# spec §3.5, §9 Phase 6 — the ASVS 5.0 / AISVS 1.0 / MLSVS / LLM Top 10
# both-epochs evidence tooling feeding the kailash verifier). The §4.5
# category module — config-only mount on the typed spine (enable +
# packages at kailash.layers.defence.categories.d-07), the KA-13.1
# exemplar shape.
#
# Binding table (probed at nixpkgs e7439b6b + packages pin ef70ec4 —
# never assumed id==attr): kailash-verifier is bespoke with a
# derivation that has NOT landed at this pin (its kailash-os
# kailash-verifier upstream is 404 at this date — the ko-record rule)
# → the bare guard drops it; it returns when its derivation lane
# lands. The three data rows (aisvs-1.0-toolkit, mlsvs-toolkit,
# llm-top10-toolkit) are EXCLUDED by the generator (the opt-in
# data-pack rule). The asvs-verification-toolkit DATA pack rides the
# c-10 primary row's surface (kailash-data; never an install set).
#
# SAFETY: every d-07 row is safety.level "safe" at this revision.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-07;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-07-standards-verification.installable;

  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (0 of the 1 installable row binds
    # at this pin — the kailash-verifier derivation is overlay-pending,
    # named above).
    kailash.layers.defence.categories.d-07.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
