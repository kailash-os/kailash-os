# CORE substrate modules (KA-18: the safety defaults ride the base fold —
# kernel, hardening, desktop-{kde,gnome,xfce} modules land per §3.4/KA-01).
{ lib, ... }: {
  imports = [
    ./safety-defaults.nix
  ];
}
