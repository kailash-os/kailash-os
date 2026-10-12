# Layer DEFENCE — D-5 AI Threat Modelling (KA-24, os#24; plan §4.5,
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
#   * atlas-visualiser — bespoke, derivation pending (its
#     kailash-os/atlas-visualiser upstream is 404 at this date — the
#     ko-record rule): drops via the bare guard, returns with its lane;
#   * genai-threat-modelling-templates, stride-ai-worksheet,
#     atlas-case-study-explorer, ai-incident-playbook-packs —
#     status:data rows, EXCLUDED by the generator (the opt-in data-pack
#     rule; never install sets).
#
# SAFETY: every d-05 row is safety.level "safe" at this revision.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-05;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-05-threat-modelling.installable;

  # No binding at this pin: maestro is the collision above (NOT bound),
  # atlas-visualiser is overlay-pending — the bare guard drops both.
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (0 of the 2 installable rows bind
    # at this pin — the maestro collision + the atlas-visualiser
    # pending lane, both named above; the four data rows sit in the
    # generator's excluded ledger).
    kailash.layers.defence.categories.d-05.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
