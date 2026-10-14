# Layer DEFENCE — D-7 Standards Verification Toolkit (KA-24, os#24;
# spec §3.5, §9 Phase 6 — the ASVS 5.0 / AISVS 1.0 / MLSVS / LLM Top 10
# both-epochs evidence tooling feeding the kailash verifier). The §4.5
# category module — config-only mount on the typed spine (enable +
# packages at kailash.layers.defence.categories.d-07), the KA-13.1
# exemplar shape.
#
# Binding table (os#210 purge, 2026-10-14): every pre-purge d-07 row
# (kailash-verifier, aisvs-1.0-toolkit, mlsvs-toolkit,
# llm-top10-toolkit, asvs-verification-toolkit) was phantom-upstream —
# the claimed kailash-os toolkit/CLI repos never existed (the OWASP
# standards THEMSELVES are real; the Kailash verification data-packs
# and CLI were not) — removed; names in the registry
# (kailash-os#210). The category is EMPTY post-purge: the rebuild
# contract returns the verifier CLI (real build, verified upstream)
# and the standards packs through the manifest gate.
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
    # The manifest-driven install set (EMPTY post-os#210: every d-07
    # row was phantom-upstream, removed).
    kailash.layers.defence.categories.d-07.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
