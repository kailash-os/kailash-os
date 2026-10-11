# Layer ATTACK AI red-team profile (KA-17.1, os#114; plan §4.2, §3.3).
#
# Composition: the CORE substrate floor (modules tree, bootable-VM floor)
# + Layer ATTACK's eight category modules + O-4 (Local LLM & Inference
# Labs) — the pairing-thesis workstation: offensive-AI tooling with its
# local inference target on the same host.
#
# Option tree note: the per-category option tree from the §4.5 module
# contract does not exist yet (category modules land with Wave-5 module
# wiring). The tree today is flat — `kailash.layers.attack.enable = true`
#
# — and this profile builds against that flat tree; the per-category
# granularity (`categories.<id>.enable`) attaches to the same option path
# when the category modules land, so this profile's intent carries over
# without a contract change.
{ lib, ... }:

{
  imports = [
    ./minimal.nix
  ];

  networking.hostName = lib.mkForce "kailash-redteam-ai";

  # Layer ATTACK in full (A-1…A-8) + O-4 — flat option tree until the
  # Wave-5 per-category wiring lands (see the header note).
  kailash.layers.attack.enable = lib.mkDefault true;
  kailash.layers.ops.categories.o-04.enable = lib.mkDefault true;
}
