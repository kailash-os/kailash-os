# Layer DEFENCE — D-6 AI Governance & Regulation Mapping (KA-24, os#24;
# plan §4.5, §9 Phase 6). The §4.5 category module — config-only mount
# on the typed spine (enable + packages at
# kailash.layers.defence.categories.d-06), the KA-13.1 exemplar shape.
#
# Binding table (probed at nixpkgs e7439b6b + packages pin ef70ec4 —
# never assumed id==attr): ai-act-compliance-checker is bespoke with a
# derivation that has NOT landed at this pin (its kailash-os upstream
# is 404 at this date — the ko-record rule) → the bare guard drops it;
# it returns when its derivation lane lands. The three data rows
# (nist-ai-rmf-toolkit, iso-42001-templates, genai-vendor-review-form)
# are EXCLUDED by the generator (the opt-in data-pack rule).
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
    # The manifest-driven install set (0 of the 1 installable row binds
    # at this pin — the ai-act-compliance-checker derivation is
    # overlay-pending, named above).
    kailash.layers.defence.categories.d-06.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
