# Layer DEFENCE — D-5 AI Threat Modelling (KA-24, os#24; spec §3.5,
# §9 Phase 6). The §4.5 category module — config-only mount on the
# typed spine (enable + packages at
# kailash.layers.defence.categories.d-05), the KA-13.1 exemplar shape.
#
# Binding table (probed at nixpkgs e7439b6b + packages pin ef70ec4 —
# never assumed id==attr):
#   * maestro — the nixpkgs top-level `maestro` attr (2.11.0) is the
#     UNRELATED mobile.dev UI-testing CLI (name collision); the
#     manifest row's upstream is agentic-threat-modeling/MAESTRO. The
#     row stays bespoke (overlay-pending); binding the colliding attr
#     would install the wrong tool — the D-4-side NATIVE_BINDINGS gate
#     records no entry for it on purpose;
#   * (os#210 purge, 2026-10-14) the pre-purge visualiser + four
#     template/data rows were phantom-upstream — their claimed
#     kailash-os repos never existed: removed; names in the
#     registry (kailash-os#210). The category's real surface is maestro
#     (upstream agentic-threat-modeling/MAESTRO, overlay-pending).
#
# SAFETY: every d-05 row is safety.level "safe" at this revision.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-05;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-05-threat-modelling.installable;

  # No binding at this pin: maestro is the collision above (NOT bound;
  # its real overlay derivation is pending) — the bare guard drops it.
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (0 rows bind at this pin — the
    # maestro collision means its real derivation is the pending lane;
    # the pre-purge data/visualiser rows were removed per os#210).
    kailash.layers.defence.categories.d-05.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
