# services.kailash.gvm — the GVM/OpenVAS vulnerability-management service
# module (KA-27, ko#27; plan §3.2 C-2).
#
# The module-status manifest row's deliverable (ko#97's explicit deferral):
# the Greenbone/GVM vulnerability manager ships as THIS service module, not
# loose tools — the c-02 category module excludes the gvm row from its
# install set (generated/manifest-ids.json excluded ledger, status
# "module") and tests/vm-smoke-tables.nix keeps it off the PATH tables.
# The issue's clause is the shape contract: "configures redis, gvmd, feed
# syncs; NOT a raw package".
#
# §3.2 C-2 surface (the full posture lands with the GREEN commit):
#   * a dedicated redis instance (services.redis.servers.kailash-gvm —
#     loopback, unix-socket only) for the vulnerability-management stack;
#   * the gvmd manager unit (the manager derivation is the module's
#     package contract — see the package option description: absent from
#     the pinned nixpkgs 8c3cede at this revision, so the module REQUIRES
#     it eval-time when enabled rather than inventing a substitute);
#   * greenbone-feed-sync units (+ timer) for the community feeds into the
#     feed state directory.
#
# Opt-in posture (the service-module rule KA-08.1's mlflow module fixed):
# enable defaults FALSE — nothing listens, no feed units, no redis
# instance, and the manager requirement is never evaluated until the
# operator declares the service.
#
# RED STUB (watched-RED discipline, ko#51): the typed enable option only,
# with an enable-only config. The §3.2 surface above (units, redis server,
# feed syncs, the package require) lands with the GREEN commit; the check
# legs this stub reds are the harness-first proof (AGENTS.md Testing, the
# harness-before-capability standard: the check ships with the behaviour,
# its RED committed before the GREEN that flips it).
{ config, lib, pkgs, ... }:

{
  options.services.kailash.gvm = {
    enable = lib.mkEnableOption ''
      the GVM/OpenVAS vulnerability-management service — the §3.2 C-2
      surface (dedicated redis instance, the gvmd manager, Greenbone feed
      syncs). Default OFF — the no-auto-start posture: nothing listens
      until the operator declares it. The recommended composition pairs
      this with the c-02 category (kailash.layers.classic.categories.c-02
      .enable)
    '';
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        The gvmd manager derivation. The package CONTRACT: gvmd is absent
        from the pinned nixpkgs at this revision (probed — only
        greenbone-feed-sync + gvm-tools exist there), so an enabled host
        MUST supply the manager derivation; the module requires it
        eval-time (the assertion + the unit-text abort) rather than
        inventing a substitute.
      '';
      example = lib.types.literalExpression "pkgs.gvmd";
    };
  };

  config = lib.mkIf config.services.kailash.gvm.enable {
    # The §3.2 C-2 stack: dedicated redis instance (unix-socket only,
    # loopback, TCP off), the gvmd manager unit behind the package
    # CONTRACT, and the Greenbone community feed-sync units.
    assertions = [
      {
        assertion = config.services.kailash.gvm.package != null;
        message = "kailash-gvm: services.kailash.gvm.package is required — gvmd is absent from the pinned nixpkgs; supply the manager derivation to compose the service";
      }
    ];

    services.redis.servers.kailash-gvm = {
      enable = true;
      bind = "127.0.0.1";
      port = 0;
      unixSocket = "/run/redis-kailash-gvm/redis.sock";
      unixSocketPerm = 660;
    };

    systemd.units."kailash-gvmd.service" = {
      description = "Kailash GVM/OpenVAS vulnerability manager (gvmd)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "redis-kailash-gvm.service" ];
      requires = [ "redis-kailash-gvm.service" ];
      text = lib.mkIf (config.services.kailash.gvm.package == null)
        (abort "services.kailash.gvm: enable=true with no manager package — the gvmd derivation is required (absent from this nixpkgs pin); set services.kailash.gvm.package");
    };

    systemd.units."kailash-gvm-feed.service" = {
      description = "Kailash GVM Greenbone community feed sync";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "kailash-gvmd.service" ];
      path = with pkgs; [ greenbone-feed-sync ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "kailash-gvm";
        ExecStart = "${pkgs.greenbone-feed-sync}/bin/greenbone-feed-sync";
      };
    };

    systemd.units."kailash-gvm-feed.timer" = {
      description = "Kailash GVM community feed sync schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "kailash-gvm-feed.service";
      };
    };
  };
}
