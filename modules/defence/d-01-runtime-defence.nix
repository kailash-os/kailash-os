# Layer DEFENCE — D-1 AI Runtime Defence & Guardrails (KA-24, os#24;
# spec §3.5, §9 Phase 6). The §4.5 category module — config-only mount
# on the typed spine (modules/base/layer-tree.nix declares enable +
# packages at kailash.layers.defence.categories.d-01), the KA-13.1
# exemplar shape (modules/attack/a-01-ai-recon.nix).
#
# Binding table (probed at nixpkgs e7439b6b + packages pin ef70ec4 —
# never assumed id==attr): NO d-01 row binds at this pin. All seven
# rows are manifest-bespoke (nemo-guardrails, llm-guard, guardrails-ai,
# rebuff, gaskunk, llm-firewall, whisper-gate) whose kailash-packages
# derivations have NOT landed (the upstreams' first-party set partly
# 404s; the rows' packages-overlay derivations are pending) — they fall
# to the bare guard, resolve null and DROP without breaking eval. Each
# row returns when its derivation lane lands in kailash-packages pkgs/
# (the exemplar's overlay-pending rule, unchanged shape).
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

  # No non-bare bindings at this pin: every bespoke row keeps the bare
  # guard (the named drops resolve null here and return with their
  # derivations).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (0 of the 7 rows bind at this pin —
    # all bespoke-overlay-pending, named above; the module and its
    # manifest surface stay wired and present either way).
    kailash.layers.defence.categories.d-01.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
