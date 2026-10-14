# services.kailash.mlflow — the MLflow tracking server (KA-08.1, ko#105;
# spec §8 Phase 3: "mlflow reachable on :5000"; issue ko#105: "MLflow
# reachable on :5000 in the VM").
#
# POSTURE (the ko#105 contract, verbatim plan clause "lab-default unauth
# documented, not defaulted"): an MLflow tracking server on
# services.mlflow's postgres/sqlite backends has NO authentication layer —
# an unauthenticated, lab-only surface (the pairing-thesis target the A-7
# mlflow-bypass probe trains against, spec §5.5). The posture is a
# DOCUMENTED opt-in, never a default:
#
#   * enable defaults FALSE — the service only runs when the operator
#     declares it (the §11.2 no-auto-start posture; exp-class routing
#     stays with the §11.2 gate — this module is safe-class tooling);
#   * the default bind is the LOOPBACK (host = 127.0.0.1): the operator
#     who wants the lab-exposed reachability moves to 0.0.0.0 as an
#     EXPLICIT, reviewable configuration change (see labReachable below);
#   * with loopback binding, Kailash's default-deny firewall
#     (base/hardening.nix, §8.3) never sees an external surface — the
#     unauth exposure is confined to the host itself;
#   * the lab-exposed posture is documented in the option descriptions
#     (labReachable) — the exact configuration operators copy, with the
#     §9 Phase-3 wording and the A-7 pairing note.
#
# Upstream shape probed at the pin: mlflow 3.16.1's CLI server is
# `mlflow server` (click group mlflow/cli/__init__.py:541 — --backend-store-uri,
# --host, --port, security middleware on by default with the localhost-only
# posture; its own help text: "To allow connections from other hosts, use
# --host 0.0.0.0 and configure --allowed-hosts and --cors-allowed-origins").
# gunicorn is a pinned hard dependency of the package (METADATA
# Requires-Dist: gunicorn<27; platform_system != Windows) — the derivation
# carries it; no extra package wiring is needed.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kailash.mlflow;

  mlflow = pkgs.python3Packages.mlflow;

  bindHost =
    if cfg.labReachable then "0.0.0.0"
    else if cfg.host != null then cfg.host
    else "127.0.0.1";
in
{
  options.services.kailash.mlflow = {
    enable = lib.mkEnableOption ''
      the MLflow tracking server (an unauthenticated lab surface on
      services.mlflow's backends — the posture is documented in
      services.kailash.mlflow.labReachable). Default OFF — the §11.2
      no-auto-start posture: nothing listens until the operator declares
      it
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3Packages.mlflow;
      defaultText = lib.literalExpression "pkgs.python3Packages.mlflow";
      description = ''
        The mlflow derivation serving the tracking server (probed at the
        pin: python3Packages.mlflow, no top-level attr). gunicorn is a
        pinned hard dependency of the package — the server CLI reaches it
        through the wrapped env without extra wiring.
      '';
    };

    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Bind address override. The DEFAULT (null) is the loopback bind
        (127.0.0.1) — the safe default for an unauthenticated surface.
        Set a specific address only with reason; the lab-exposed posture
        rides labReachable instead.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = ''
        TCP port of the tracking server (the ko#105 acceptance clause:
        reachable on :5000).
      '';
    };

    labReachable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        THE DOCUMENTED LAB POSTURE (never defaulted — spec §8 Phase 3:
        "lab-default unauth documented, not defaulted"). The lab-exposed
        configuration an operator copies for the pairing-thesis lab (the
        A-7 mlflow-bypass surface, spec §5.5):

            services.kailash.mlflow = {
              enable = true;
              labReachable = true;   # binds 0.0.0.0 — unauthenticated
            };

        MLflow's tracking server carries NO authentication layer on its
        backends: with labReachable the server is an UNAUTHENTICATED,
        network-exposed surface (upstream's own guidance: --host 0.0.0.0
        "and configure --allowed-hosts and --cors-allowed-origins").
        Lab machines only. Never on a host with a default-route
        interface beyond the lab segment. The production posture (§11.2
        hardening appendix) keeps labReachable = false and puts an
        authenticating reverse proxy in front instead.
      '';
    };

    backendStoreUri = lib.mkOption {
      type = lib.types.str;
      default = "sqlite:///${cfg.stateDir}/mlflow.db";
      defaultText = lib.literalExpression "sqlite:///\${config.services.kailash.mlflow.stateDir}/mlflow.db";
      description = ''
        Backend store URI (the tracking database). Default: the sqlite
        store under stateDir. Set a postgresql:// URI for a shared
        backend (services.mlflow's own guidance for team servers).
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/kailash-mlflow";
      description = ''
        State directory — the sqlite backend store and the default
        artifact root live under it (systemd StateDirectory, so the
        directory is created, owned and persisted for the service).
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open the firewall for the tracking-server port. Default OFF —
        stays false even in the lab posture unless the lab segment needs
        it; loopback binding needs no firewall hole at all.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.kailash.mlflow.package = lib.mkDefault mlflow;

    assertions = [
      {
        assertion = !(cfg.labReachable && cfg.host != null);
        message = ''
          services.kailash.mlflow: set EITHER labReachable (the documented
          0.0.0.0 lab bind) OR an explicit host — never both.
        '';
      }
    ];

    systemd.services.kailash-mlflow = {
      description = "Kailash MLflow tracking server (unauthenticated lab surface)";
      documentation = [ "https://mlflow.org/docs/latest/self-hosting/architecture/tracking-server" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Artifacts land under the state directory: the CLI defaults the
      # artifact root relative to the working directory (./mlartifacts)
      # and serviceConfig pins WorkingDirectory to the StateDirectory —
      # no invented env vars, the backend store rides the CLI flag below.
      script = ''
        ${cfg.package}/bin/mlflow server \
          --host ${bindHost} \
          --port ${toString cfg.port} \
          --backend-store-uri ${cfg.backendStoreUri}
      '';

      serviceConfig = {
        Type = "simple";
        StateDirectory = "kailash-mlflow";
        WorkingDirectory = cfg.stateDir;
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.stateDir ];
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        NoNewPrivileges = true;
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
