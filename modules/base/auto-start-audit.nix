# No-auto-start audit (KA-18.2, os#93; spec §9.2) — the standing check.
#
# Contract: no service in this flake auto-starts exp-class tooling. A
# service is a violation when it is wanted into a boot target AND either
# references a policed exp tool name in its ExecStart or pre-sets the
# KAILASH_LAB_MODE shell key (an autostart bypass of the lab gate).
#
# The audit record: option `kailash.audit.autoStart.violations` carries the
# finding list; the flake's audit-auto-start-clean check requires an empty
# list on every real profile, and the hostile-fixture check proves the
# scanner catches a violator (the negative case is proven in CI, never
# asserted — engineering standard).
#
# Scope note: the scan walks this host's systemd.services definitions (the
# declarative surface) — runtime units created outside the flake are a VM
# concern, not an eval-time one.
{ config, lib, ... }:

let
  cfg = config.kailash.audit.autoStart;
in
{
  options.kailash.audit.autoStart = {
    expToolNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Exp-class tool names the audit polices (host-declared; product
        wiring joins the safety surface at Wave-5). A service whose
        ExecStart references one of these names while wanted into a boot
        target is an auto-start violation.
      '';
    };

    violations = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Audit findings, one per offending service:
        "service <name> auto-starts exp tooling (<reason>)". The standing
        gate requires this list EMPTY on every profile.
      '';
    };
  };

  config = {
    # The scan: per-service walk of the declarative systemd services. A
    # service is a violation when it is wanted into a boot target
    # (wantedBy non-empty) AND its command line references a policed exp
    # tool (ExecStart/ExecStartPre/ExecStartPost/script) or pre-sets the
    # lab shell key in any of its command or environment fields.
    kailash.audit.autoStart.violations =
      let
        bootTargets = [ "multi-user.target" "graphical.target" "default.target" ];

        # Every command-ish string a service unit carries; flattened to
        # strings (ExecStart etc. may be a list of str or a single str).
        execStrs = v:
          if v == null then [ ]
          else if lib.isList v then map toString (lib.filter (x: x != null) v)
          else [ (toString v) ];

        commandsOf = svc:
          lib.concatMap execStrs [
            (svc.serviceConfig.ExecStart or null)
            (svc.serviceConfig.ExecStartPre or null)
            (svc.serviceConfig.ExecStartPost or null)
            (svc.script or null)
            (svc.preStart or null)
            (svc.postStart or null)
          ];

        wantedIntoBoot = svc:
          lib.any (t: lib.elem t bootTargets) (svc.wantedBy or [ ]);

        cmdBlob = svc: lib.concatStringsSep " " (commandsOf svc);

        touchesPolicedTool = svc:
          lib.concatMap
            (tool:
              if tool != "" && lib.any (cmd: lib.hasInfix tool cmd) (commandsOf svc)
              then [ tool ] else [ ])
            cfg.expToolNames;

        preSetsLabKey = svc:
          lib.hasInfix "KAILASH_LAB_MODE" (cmdBlob svc)
          || lib.hasInfix "KAILASH_LAB_MODE"
            (lib.concatStringsSep " "
              (lib.mapAttrsToList (k: v: "${k}=${toString v}")
                (svc.environment or { })));

        findings = lib.mapAttrsToList
          (name: svc:
            let
              matchedTools = touchesPolicedTool svc;
              reasons = lib.filter (r: r != null) [
                (if matchedTools != [ ]
                then "ExecStart references policed exp tool(s): ${lib.concatStringsSep ", " matchedTools}"
                else null)
                (if preSetsLabKey svc then "pre-sets KAILASH_LAB_MODE" else null)
              ];
            in
            if wantedIntoBoot svc && reasons != [ ]
            then "service ${name} auto-starts exp tooling (${lib.concatStringsSep "; " reasons})"
            else null)
          config.systemd.services;
      in
      lib.filter (v: v != null) findings;
  };
}
