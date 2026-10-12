# Layer DEFENCE category modules (§4.2 fold + §4.5 contract). The full
# D-1…D-7 set lands with KA-24 (os#24): one §4.5 category module per
# manifest category — `options.kailash.layers.defence.categories.<id>`
# composed config-only (the KA-09.1 typed spine declares the
# enable/packages baseline members). New category modules join this
# import list.
{ lib, ... }: {
  imports = [
    ./d-01-runtime-defence.nix
    ./d-02-detection-monitoring-observability.nix
    ./d-03-assurance-evals-benchmarks.nix
    ./d-04-provenance-signing-trust.nix
    ./d-05-threat-modelling.nix
    ./d-06-governance-regulation-mapping.nix
    ./d-07-standards-verification.nix
  ];
}
