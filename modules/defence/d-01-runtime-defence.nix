# Layer DEFENCE — D-1 AI Runtime Defence & Guardrails (KA-24, os#24;
# spec §3.5, §9 Phase 6). The §4.5 category module — config-only mount
# on the typed spine (modules/base/layer-tree.nix declares enable +
# packages at kailash.layers.defence.categories.d-01), the KA-13.1
# exemplar shape (modules/attack/a-01-ai-recon.nix).
#
# Binding table (os#210 purge update 2026-10-14): three of the seven
# pre-purge guard rows claimed kailash-os upstream repos that were never
# created — the os#210 audit removed them as phantom rows, names in the
# registry (kailash-os#210).
# The four real rows (nemo-guardrails, llm-guard, guardrails-ai,
# rebuff — upstreams NVIDIA-NeMo/Guardrails, protectai/llm-guard,
# guardrails-ai/guardrails, protectai/rebuff) keep manifest-bespoke
# rows whose kailash-packages derivations have NOT landed — bare-guard
# drops until their lanes land.
#
# SAFETY (§11.2; recorded per row from the manifest — the manifest is
# the single home of the facts): every d-01 row is safety.level "safe"
# at this revision; no exp-class row rides this install set (the
# lab-mode gate owns that surface by construction).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-01;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-01-runtime-defence.installable;

  # Bare guard: every bespoke row (the four real, upstream-verified
  # rows) keeps the bare guard (the named drops resolve null here and
  # return with their derivations).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (0 of the 4 rows bind at this pin —
    # all bespoke-overlay-pending; the three phantom rows were removed
    # per os#210. The module stays wired and present either way).
    kailash.layers.defence.categories.d-01.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
