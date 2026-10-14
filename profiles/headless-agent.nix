# The headless-agent profile (KA-28, kailash-os#28; spec §7.1 row 4).
#
# "base + CLI, no desktop" — the boot-to-agent target: the CORE substrate
# floor (zero categories on) + the manifest-aware kailash CLI (the packages
# overlay's §7.1 first-party source, verified present at the current pin).
# Per the ratified deliverable-shape decision (kailash-os#132) the QEMU
# image is the PRIMARY artifact for this profile (KA-32's golden-input
# reproducibility gate + KA-43's headless-agent boot polish) and the ISO is
# the secondary bootable surface.
#
# No desktop and no GUI stack is installed (the §4.5 tree stays all-off —
# the minimal import is the whole floor). The desktop-carrying iso-standard /
# iso-lite variants of spec §7.1 land with their desktop modules (KA-01
# wave, §3.4), not here.
{ lib, pkgs, ... }:

{
  imports = [ ./minimal.nix ];

  networking.hostName = lib.mkForce "kailash-headless-agent";

  # The CLI agent surface: `packages.kailash` (the packages overlay's
  # manifest-aware CLI — kailash list/search/info/profile list). Null-guarded
  # so the profile evaluates at any overlay pin; at the current pin it
  # resolves (kailash 0.1.0, verified).
  environment.systemPackages = lib.filter (p: p != null) [
    (pkgs.kailash or null)
  ];
}
