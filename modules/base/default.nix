# CORE substrate modules (KA-17/KA-18: the layers option tree (KA-17.1)
# and the safety gate (KA-18.1/#144) ride the base fold — kernel,
# desktop-{kde,gnome,xfce} modules land per §3.4/KA-01).
#
# hardening.nix (KA-17.2, os#115) carries the §8.3 CORE posture: the
# kernel-exposure sysctl set, a default-deny firewall, and the
# wheel-only sudo policy — inherited by every profile through this fold.
{ lib, ... }: {
  imports = [
    ./layer-tree.nix
    ./safety-defaults.nix
    ./auto-start-audit.nix
    ./secrets-hygiene.nix
    ./hardening.nix
  ];
}
