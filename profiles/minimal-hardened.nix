# The hardened minimal profile (KA-17.2, os#115; plan §9 Phase-5 image
# posture, §11.2 safety posture).
#
# Composition: the CORE substrate floor (profiles/minimal.nix — the
# module tree, bootable-VM floor) with the hardening posture PINNED
# explicitly:
#
#   * kailash.labMode = false  — the host-side key of the lab-mode
#     double-key gate (KA-18.1) pinned OFF: this profile is the named,
#     reviewable statement that the host is NOT a lab host. The default
#     is already false; the pin makes the posture an audit-visible
#     property of the profile instead of a default a later drift could
#     silently change.
#
# Everything else is inherited: the §8.3 hardening module
# (modules/base/hardening.nix — sysctl, firewall default-deny, wheel-only
# sudo) rides the base fold from modules/base/default.nix; safety
# defaults, the no-auto-start audit, and secrets hygiene ride the same
# fold. Zero categories are enabled — the tool substrate installs, no
# tool-layer switch is on. Higher profiles (redteam-ai today) compose
# above this floor; the hardened floor is what the iso-standard/iso-lite
# cuts bake first.
#
# NOTE (ko#115 CLI-side follow-through): `kailash profile list` (the
# packages-repo CLI stub) reads a profiles.json baked per-file via
# KAILASH_PROFILES; the sample profiles.json row for this profile lives
# in the packages repo until that bake lands.
{ lib, ... }:

{
  imports = [
    ./minimal.nix
  ];

  # The posture pin: see the header. (The default is already false —
  # this is the audit-visible pin, not a behaviour change.)
  kailash.labMode = false;

  networking.hostName = lib.mkForce "kailash-minimal-hardened";
}
