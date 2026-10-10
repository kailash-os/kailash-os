# The CORE substrate profile (KA-01.3): imports the category module tree and
# enables nothing — every category option defaults to false, so the base
# substrate is all that installs. Higher profiles (full, redteam-ai,
# blue-team-ai, platform) import this file and switch categories on above
# this floor.
{ ... }:

{
  imports = [ ../modules ];

  networking.hostName = "kailash-minimal";

  # Bootable-VM floor: placeholder QEMU-style EFI root. The root device and
  # loader are overridden per target — image formats (nixos-generators +
  # disko) in the images wave, real-hardware profiles above this floor.
  fileSystems."/" = {
    device = "/dev/disk/by-label/kailash";
    fsType = "ext4";
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "25.11";
}
