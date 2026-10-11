# Synthetic safety-gate fixture (KA-18.1, os#92) — NOT a product profile.
#
# Provides the RED/GREEN material for the lab-mode gate's checks: a
# synthetic safety:exp-class tool derivation (kailash-safety-fixture) whose
# marker binary the gate legs exec to prove the refusal wording (the "real
# run output" acceptance clause).
#
# Never imported by modules/ or product profiles; consumed only by the
# safety-exp-* checks in flake.nix.
{ lib, pkgs, ... }:

{
  kailash.safety.extraTools = [
    (pkgs.runCommand "kailash-safety-fixture"
      {
        meta.mainProgram = "kailash-fixture-exp";
      }
      ''
        mkdir -p $out/bin
        printf '#!/bin/sh\necho FIXTURE-EXP-TOOL-RAN "$@"\n' > $out/bin/kailash-fixture-exp
        chmod +x $out/bin/kailash-fixture-exp
      '')
  ];
}
