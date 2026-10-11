# No-auto-start audit (KA-18.2, os#93; plan §11.2) — the standing check.
#
# Contract: no service in this flake auto-starts exp-class tooling. A
# service is a violation when it is wanted into a boot target AND either
# references an exp tool in ExecStart or pre-sets the KAILASH_LAB_MODE
# shell key (an autostart bypass of the lab gate).
#
# The audit record: option `kailash.audit.autoStart.violations` carries the
# finding list; the flake's audit-auto-start-clean check requires an empty
# list on every real profile, and the hostile-fixture check proves the
# scanner catches a violator (the negative case is proven in CI, never
# asserted — engineering standard).
#
# RED stub: the scanner reports no violations and the hostile-fixture check
# fails ("autostart not caught") until the GREEN commit implements the scan.
{ config, lib, ... }:

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
    # RED stub: the scan lands with the GREEN commit; until then the
    # audit reports nothing (the hostile-fixture check fails loudly —
    # the watched RED).
    kailash.audit.autoStart.violations = [ ];
  };
}
