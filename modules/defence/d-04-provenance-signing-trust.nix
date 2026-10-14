# Layer DEFENCE — D-4 Model Provenance, Signing & Trust (KA-24, os#24;
# spec §3.5, §9 Phase 6 — the cosign/sigstore/modelsign/cdxgen AI-BOM
# flow). The §4.5 category module — config-only mount on the typed
# spine (enable + packages at kailash.layers.defence.categories.d-04),
# the KA-13.1 exemplar shape.
#
# Binding table (probed at nixpkgs e7439b6b + packages pin ef70ec4 —
# never assumed id==attr): SEVEN rows bind natively at this pin —
#   cosign 3.1.3, syft 1.54.0, grype 0.120.0, trivy 0.74.0,
#   cyclonedx-cli 0.32.0, cdxgen 13.0.1 (all bare), modelsign via
#   python3Packages.model-signing (1.1.1, unbroken — NATIVE with the
#   KA-24 probe-receipt flip landed, kailash-packages#54);
# the three pending bespoke rows (sigstore-tools — upstream 404 at
# this date, the ko-record rule; hf-repo-auditor + model-card-toolkit
# — derivations pending) drop via the bare guard and return with
# their lanes.
#
# SAFETY: every d-04 row is safety.level "safe" at this revision.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.defence.categories.d-04;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.d-04-provenance-signing-trust.installable;

  # The one non-bare binding at this pin (the sigstore pypi name).
  attrFor = id:
    {
      "modelsign" = pkgs.python3Packages.model-signing or null;
    }.${id} or (pkgs."${id}" or null);

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (7 of the 10 rows bind at this
    # pin: the six bare natives + modelsign via python3Packages;
    # sigstore-tools, hf-repo-auditor, model-card-toolkit are
    # overlay-pending drops, named above).
    kailash.layers.defence.categories.d-04.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
