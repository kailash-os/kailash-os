# The §8.1 image generator (KA-28, kailash-os#28): one source profile eval,
# two formats (the ratified [kailash-os#132](https://github.com/kailash-os/kailash-os/issues/132)
# decision — QEMU image PRIMARY, bootable ISO secondary), nixos-generators
# as the plan §8.1 names (the input rides flake.nix and this module binds
# it at the call site, so hosted eval never re-resolves).
#
# Per target: the EXACT nixos-generators composition (format module + the
# profile module) evaluated through nixpkgs' nixosSystem with the SAME
# overlay'd pkgs the product nixosConfigurations evaluate with (§4.5
# binding tables read the composed overlay), then the formatAttr derivation
# is the image artifact and `system.build.toplevel` is the evaluated
# per-profile closure (the budget census walks it).
#
# WHY THE PER-FORMAT FIXTURE MODULES: the profile floors (profiles/minimal.nix
# "Bootable-VM floor") are PLAIN definitions (priority 100):
#
#   * the qcow-efi format sets fileSystems."/" plain ("/dev/disk/by-label/nixos")
#     — a PLAIN-vs-PLAIN conflict at eval (probed: the qcow formats throw
#     "conflicting definition values" against the profile floor);
#   * the iso format's live-media fileSystems ride mkImageMediaOverride
#     (priority 900) — they LOSE SILENTLY to the profile's plain floors: the
#     eval stays green and the "live" ISO would boot with a hard-disk fstab
#     (broken at runtime, never asserted).
#
# So each shipped format carries an explicit floor-adaptation module that
# IMPOSES the format's floor at mkForce (priority 50 — no conflicts, plain
# floors yield silently). The loaders follow the format's own tested shape:
# qcow-efi → GRUB EFI removable-install (no NVRAM needed — sandbox/CI-safe);
# iso → the ISO module's own loader posture (grub disabled upstream-side;
# systemd-boot is forced off for the live surface).
#
# The diskSize is per-target build headroom (make-disk-image fills the
# filesystem to the closure, then the qcow2 GROWS at first boot via
# autoResize + growPartition); the §8.1 BUDGETS are on the artifact mass,
# owned by the images-budget check leg (census + require, not this knob).
{
  lib,
  nixos-generators,
  pkgsLinux,
  armPkgs ? pkgsLinux,
  profilesTable ? import ./kailash-images-table.nix,
}:

let
  formatIds = {
    qemu = "qcow-efi"; # the UEFI-capable qcow2 (make-disk-image, "efi" table)
    iso = "iso"; # the installer/live ISO (iso-image.nix)
  };

  # The per-format fixture modules (the floors the formats need, imposed):
  formatModules = {
    qemu = { config, lib, ... }: {
      # The disk floor the qcow-efi format installs (mirrored verbatim,
      # imposed at mkForce so the profile's plain floors compose into the
      # image shape):
      fileSystems = lib.mkForce {
        "/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
          autoResize = true;
        };
        "/boot" = {
          device = "/dev/disk/by-label/ESP";
          fsType = "vfat";
        };
      };
      # Loaders: the format's own tested shape — GRUB EFI with
      # removable-install (writes no NVRAM: builds clean in the sandbox,
      # boots from UEFI firmware). The profile's systemd-boot floor stays
      # for standalone nixosConfigurations hosts (evaluated separately);
      # the image composition pins the format's shape.
      boot.loader.grub = lib.mkForce {
        enable = true;
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
      # The VM/serial posture (the format's consoles carry ttyS0; pinned so
      # an upstream default flip cannot silently drop it).
      boot.kernelParams = [ "console=ttyS0,115200" ];
    };

    iso = { lib, ... }: {
      # The live-media floor, mirrored from iso-image.nix's
      # config.lib.isoFileSystems and imposed at mkForce (the upstream
      # module's mkImageMediaOverride LOSES to the profile's plain floors —
      # the silent-loss trap in the header). Values copied verbatim from the
      # pinned module's table (incl. the systemd-stage-1 /iso device form —
      # boot.initrd.systemd defaults true at this pin).
      fileSystems = lib.mkForce {
        "/" = {
          fsType = "tmpfs";
          options = [ "mode=0755" ];
        };
        "/iso" = {
          device = "/dev/disk/by-label/${"KAILASH_LIVE"}";
          fsType = "iso9660";
          neededForBoot = true;
          noCheck = true;
        };
        "/nix/.ro-store" = {
          fsType = "squashfs";
          device = "/sysroot/iso/nix-store.squashfs";
          options = [ "loop" "threads=multi" ];
          neededForBoot = true;
        };
        "/nix/.rw-store" = {
          fsType = "tmpfs";
          options = [ "mode=0755" ];
          neededForBoot = true;
        };
        "/nix/store" = {
          overlay = {
            lowerdir = [ "/nix/.ro-store" ];
            upperdir = "/nix/.rw-store/store";
            workdir = "/nix/.rw-store/work";
          };
        };
      };
      # The live surface boots no installed loader: the ISO module's
      # own grub-disable rides mkImageMediaOverride (which the profile's
      # plain floor would override) — forced here.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
      # The §8.1 ISO posture in the format module (profile-agnostic).
      isoImage.volumeID = lib.mkDefault "KAILASH_LIVE";
      isoImage.makeBiosBootable = lib.mkDefault true;
      isoImage.makeEfiBootable = lib.mkDefault true;
      isoImage.makeUsbBootable = lib.mkDefault true;
    };
  };

  # One §8.1 target: the generator composition, the artifact derivation
  # AND the evaluated per-profile toplevel (the census walk surface).
  # OPTIONAL per-target system (KA-36, kailash-os#198): x86_64-linux by
  # default (the hosted-release posture, release-images.yml); arm targets
  # carry `system = "aarch64-linux"` — they build LOCALLY on Apple
  # Silicon (the standing arch strategy: x86 hosted, arm local — the
  # lane Mac runs aarch64-linux derivations natively, no emulation).
  # The generator receives BOTH pkgs slices from the flake (armPkgs is
  # the flake's aarch64-linux nixpkgs — pinned, same lock); passing the
  # x86 slice into an aarch64 nixosSystem is a contradiction, so each
  # target picks its platform's slice.
  mkTarget = name: target:
    let
      formatModule = builtins.getAttr formatIds.${target.format} nixos-generators.nixosModules;
      image = lib.nixosSystem {
        system = target.system or "x86_64-linux";
        pkgs = if (target.system or "x86_64-linux") == "aarch64-linux"
          then armPkgs
          else pkgsLinux;
        modules = [
          formatModule
          formatModules.${target.format}
          (../profiles + "/${target.profile}.nix")
        ];
      };
    in {
      image = image.config.system.build.${image.config.formatAttr};
      toplevel = image.config.system.build.toplevel;
      config = image.config;
    };

  perTarget = lib.mapAttrs mkTarget profilesTable.targets;
in {
  # The artifact derivations (one per §8.1 target — `nix build` surface).
  images = lib.mapAttrs (_: t: t.image) perTarget;
  # The evaluated per-profile toplevels (the census surface).
  toplevels = lib.mapAttrs (_: t: t.toplevel) perTarget;
}
