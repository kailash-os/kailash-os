<<<<<<< HEAD
# CORE substrate modules (KA-18: the safety defaults ride the base fold —
# kernel, hardening, desktop-{kde,gnome,xfce} modules land per §3.4/KA-01).
{ lib, ... }: {
  imports = [
    ./safety-defaults.nix
=======
# CORE substrate modules (KA-18: the no-auto-start audit + secrets hygiene
# ride the base fold — kernel, hardening, desktop modules land per
# §3.4/KA-01; safety-defaults.nix lands with KA-18.1/#144).
{ lib, ... }: {
  imports = [
    ./auto-start-audit.nix
    ./secrets-hygiene.nix
>>>>>>> 4875397 (feat(safety): RED - no-auto-start audit stub, sops skeleton, responsible-use data file)
  ];
}
