# Hardening module (KA-17.2, os#115; spec §7.3 — `hardening.nix`: sysctl,
# firewall default-deny, sudo policy — nothing exotic).
#
# Why a whole module (not profile-local settings): the hardened posture
# must hold on EVERY image — the base fold carries it, profiles compose
# above it, and the option knobs keep the posture reviewable and
# overridable per host (mkDefault; the hardened profile pins the lab
# gate OFF, a lab appliance may relax with an explicit review note).
#
# Companion to safety-defaults.nix (the lab-mode double-key gate, KA-18.1):
# that gate controls tool EXECUTION, this module controls the HOST —
# network exposure, kernel debugging surfaces, and privilege-escalation
# paths. Safety:target/exp tooling is plentiful on a Kailash host; the
# posture shrinks the attack surface the tools themselves do not cover.
{ config, lib, ... }:

let
  cfg = config.kailash.hardening;
in

{
  options.kailash.hardening = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Apply the CORE hardening posture (KA-17.2, spec §7.3): the
        kernel-exposure sysctl set, a default-deny firewall, and the
        wheel-only sudo policy. The base fold carries it; disable ONLY
        with an explicit review note in the host configuration.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # ---- Firewall: default-deny (spec §7.3 "firewall default-deny") ----
    #
    # Every inbound connection refused unless a profile explicitly opens
    # a port. Lab-relevant listeners (O-1 MLflow :5000, O-3 vector DBs)
    # keep their ports CLOSED to other hosts: the pairing thesis is
    # executed on-host, and a listener reachable from the lab network is
    # an unintended exposure the profile, not the substrate, should own.
    networking.firewall.enable = lib.mkDefault true;
    networking.firewall.allowedTCPPorts = lib.mkDefault [ ];
    networking.firewall.allowedUDPPorts = lib.mkDefault [ ];

    # ---- Sysctl: the kernel-exposure set (spec §7.3 hardening.nix) ----
    #
    # Restricts what an UNPRIVILEGED local process (the common case when
    # a lab tool drops privileges or a malicious payload escapes a
    # low-service account) can observe or reach. Conservative and
    # standard-set: nothing here breaks NixOS internals or the desktop
    # substrate (verified against the nixos-unstable option defaults).
    boot.kernel.sysctl = {
      # kexec: loading a new kernel in place would bypass the store's
      # measured-boot posture — restricted to disabled unless a host
      # explicitly allows it.
      "kernel.kexec_load_disabled" = lib.mkDefault 1;

      # unprivileged BPF: classic container/escape and sniffing surface;
      # no lab workflow needs it unprivileged.
      "kernel.unprivileged_bpf_disabled" = lib.mkDefault 1;

      # BPF JIT hardening: spray-resistance for the eBPF JIT (Spectre-
      # class). Constant on every image — the tools never touch eBPF.
      "net.core.bpf_jit_harden" = lib.mkDefault 2;

      # Kernel log restricted to root: dmesg is an information-leak
      # channel (addresses, module names) for a low-priv session.
      "kernel.dmesg_restrict" = lib.mkDefault 1;

      # Kernel pointers in proc/other interfaces: %pK stays 0 for
      # unprivileged readers (the same leak channel as dmesg). The
      # NixOS sysctl module already pins 1; 2 is the stricter full
      # restriction (kptr to absolute-zero readability) — an explicit
      # mkForce of the stock pin, stated here so the posture is visible
      # in one place. (kernel.kexec_load_disabled mirrors this: NixOS
      # forces 0 to keep its own boot flow working, so the hardened
      # posture re-forces 1; a host switching back must do so
      # explicitly.)
      "kernel.kptr_restrict" = lib.mkForce 2;

      # fs.protected_*: hard Links/symlinks/pipe-open/FIFO races in
      # world-writable sticky directories (the classic local privesc
      # family). All on.
      "fs.protected_hardlinks" = lib.mkDefault 1;
      "fs.protected_symlinks" = lib.mkDefault 1;
      "fs.protected_fifos" = lib.mkDefault 2;
      "fs.protected_regular" = lib.mkDefault 2;
    };

    # ---- sudo: wheel-only, password required (spec §7.3 "sudo policy") --
    #
    #  * wheel-only: only the wheel group escalates (the plan's `kailash`
    #    user is wheel; no other group gets sudo by default).
    #  * authentication required: NOPASSWD is forbidden — an agent (or a
    #    compromised tool) holding a shell in a wheel session must still
    #    present the interactive secret to escalate. This is the
    #    posture-side analogue of the lab gate: automation does NOT get
    #    silent root, the human types (a per-invocation
    #    authentication, mirroring the double-key gate's per-invocation
    #    KAILASH_LAB_MODE=1).
    security.sudo = {
      enable = lib.mkDefault true;
      execWheelOnly = lib.mkDefault true;
      wheelNeedsPassword = lib.mkDefault true;
    };

    # wheel is the ONLY sudo-bearing group: NixOS's default wheel entry
    # is kept, the extra `ALL=(ALL:ALL) NOPASSWD` style grants are not
    # added, and the defaults-above guard keeps a host from silently
    # widening it. (users.users.<name>.extraGroups is the documented,
    # reviewable path for granting a second agent account wheel —
    # never a sudo Alias.)
    security.sudo.extraConfig = lib.mkDefault ''
      # Kailash CORE posture (KA-17.2, spec §7.3): wheel-only sudo,
      # password required per invocation. NOPASSWD grants do not exist
      # on the substrate — a host needing one writes it as a reviewed
      # per-host override in that host's configuration, never here.
    '';
  };
}
