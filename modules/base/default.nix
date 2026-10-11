# CORE substrate modules (KA-18: the safety gate (KA-18.1/#144) and the
# no-auto-start audit + secrets hygiene (KA-18.2) ride the base fold —
# kernel, hardening, desktop-{kde,gnome,xfce} modules land per §3.4/KA-01).
{ lib, ... }: {
  imports = [
    ./safety-defaults.nix
    ./auto-start-audit.nix
    ./secrets-hygiene.nix
  ];
}
