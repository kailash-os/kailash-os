# CORE substrate modules (KA-17/KA-18: the layers option tree (KA-17.1)
# and the safety gate (KA-18.1/#144) ride the base fold — kernel,
# hardening, desktop-{kde,gnome,xfce} modules land per §3.4/KA-01; the
# audit/secrets modules land with KA-18.2).
{ lib, ... }: {
  imports = [
    ./layer-tree.nix
    ./safety-defaults.nix
    ./auto-start-audit.nix
    ./secrets-hygiene.nix
  ];
}
