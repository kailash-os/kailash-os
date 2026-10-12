# Layer CLASSIC category modules (§4.2 fold + §4.5 contract). Each file
# is one §4.5 category module: `options.kailash.layers.classic.categories.<id>`
# composed config-only (the KA-09.1 spine declares the enable/packages
# baseline members) — the exemplar first (KA-06.1, ko#96), the second
# four off it (KA-06.2, ko#97). New category modules join this import list.
{ lib, ... }: {
  imports = [
    ./c-01-information-gathering.nix
    ./c-02-vulnerability-analysis.nix
    ./c-03-web-application-assessment.nix
    ./c-04-database-assessment.nix
    ./c-06-reverse-engineering.nix
    ./c-07-signal-sdr.nix
    ./c-05-password-offline-credential.nix
  ];
}
