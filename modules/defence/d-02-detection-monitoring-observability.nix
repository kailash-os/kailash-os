# Layer DEFENCE — D-2 AI Detection, Monitoring, Observability & IR
# (KA-24, os#24; spec §3.5, §9 Phase 6). The §4.5 category module —
# config-only mount on the typed spine (enable + packages at
# kailash.layers.defence.categories.d-02), the KA-13.1 exemplar shape.
#
# Binding table (probed at nixpkgs e7439b6b + packages pin ef70ec4 —
# never assumed id==attr):
#   * langfuse → status:module — the row's OWN service module owns it
#     (the generator's STATUS_OWNER ledger; never a package-list
#     surface; a services.kailash.langfuse module is NOT part of this
#     lane — the manifest row stays module-rowed, present, unwired as a
#     package list, exactly like mlflow's pre-KA-08.1 posture);
#   * phoenix, whylogs, evidently, otel-ai (openllmetry),
#     giskard (os#210 purge: prompt-injection-detector-bert +
#     canary-token-generator were phantom-upstream, removed;
#     registry: kailash-os#210) —
#     manifest-bespoke, derivations NOT landed at this pin → the bare
#     guard drops them (named, per-row); each returns with its lane.
#
# SAFETY: every d-02 row is safety.level "safe" at this revision.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-02;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-02-detection-monitoring-observability.installable;

  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (0 of the 7 installable rows bind
    # at this pin; langfuse is module-owned and never in the list).
    kailash.layers.defence.categories.d-02.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
