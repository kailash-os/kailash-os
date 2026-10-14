# Secrets hygiene (KA-18.2, os#93; spec §9.2) — the sops-nix skeleton.
#
# Declarative secret management via sops-nix (the flake input is already
# pinned): `kailash.secrets.sopsFile` wires a host's encrypted secret file;
# the module defaults to the config-class and keeps the store clean of
# secrets. Model API keys are read at RUNTIME from ~/.config/kailash/keys/
# by the consuming tools — never materialised into the store (store paths
# are world-readable; spec §9.2).
#
# Class posture (documented defaults, never defaulted weakness):
#   * service module defaults stay mkEnableOption-off — the D-layer service
#     modules consume this file's posture when they land;
#   * lab-default weaknesses are documented, never default-on.
{ config, lib, ... }:

{
  options.kailash.secrets = {
    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        The host's sops-encrypted secrets file wired into sops-nix.
        Null keeps the skeleton inert (no secrets declared). Wiring a file
        is the host's explicit act; nothing here generates or defaults one.
      '';
    };

    runtimeKeyDir = lib.mkOption {
      type = lib.types.str;
      default = "~/.config/kailash/keys";
      description = ''
        Runtime location for model API keys — read by tools at invocation
        time, never written into the store (store paths are
        world-readable).
      '';
    };
  };

  config = lib.mkMerge [
    # The runtime-key convention is stated on every host (a motd line is
    # the lightest carrier; full rendering lands with the desktop wave).
    {
      environment.etc."kailash/secrets-policy".text = ''
        kailash secrets hygiene (spec §9.2):
        - declarative secrets: sops-nix (kailash.secrets.sopsFile)
        - model API keys: read at runtime from ${config.kailash.secrets.runtimeKeyDir}
        - nothing secret lives in the Nix store (paths are world-readable)
      '';
    }
  ];
}
