# Agent capability grants v1 (KA-25, os#25; plan §3.5 O-7, §11.2 — the
# "Agent capability grants" bullet). The §11.2 posture, as an option
# tree + a minted state file + a checker script:
#
#   * Autonomous operator sessions hold SHORT-LIVED HUMAN-MINTED grants
#     scoping enable-able categories, service start, and exp execution;
#   * unsupervised agents can list/search/read only (the kailash CLI's
#     read-only commands + kailash-mcp's read-only MCP tools need NO
#     grant — the default posture grants nothing else);
#   * grant-scoped actions logged (one JSON line per decision —
#     allow AND deny — via kai-grant and the kailash-mcp face);
#   * deny-by-default: every named holder starts with NO scope; the
#     grants state is the ONLY mint surface (declared in the host
#     configuration — reviewable, never a runtime write) with an
#     expiry window (notAfter REQUIRED for any non-read holder at v1 —
#     no unlimited-window grant exists).
#
# DESIGN (v1, deliverable-shape decision): the module MINTS
# /etc/kailash/grants/grants.json into the closure from the declared
# holders and installs `kai-grant` (modules/base/kai-grant-cli.py — the
# checker: verify a holder+action against the minted state; the expiry
# window enforced; the decision line logged). Grant-scoped tool
# execution rides §11.2 unchanged: kai-grant NEVER bypasses the
# lab-mode double-key gate — the host key kailash.labMode and the
# shell key KAILASH_LAB_MODE both remain required for exp tooling
# regardless of any grant; a grant is one more door, not a key.
#
# The MCP face (kailash.mcp_server — the kailash-mcp derivation from
# the packages overlay) consumes the same file through its env
# contract; this module bakes the minted store path into the installed
# kailash-mcp wrapper's KAILASH_GRANTS so the OS option tree and the
# MCP server serve ONE grant truth (the §7.3 per-file bake shape the
# manifest-bake established).
{
  config, lib, pkgs, ... }:

let
  cfg = config.kailash.agentGrants;

  mintGrant = name: g: {
    categories = g.categories;
    tools = g.tools;
    allow_exp = g.allowExp;
    allow_service_start = g.allowServiceStart;
    read_only_only = g.readOnlyOnly;
    not_before = if g.notBefore == null then null else g.notBefore;
    not_after = if g.notAfter == null then null else g.notAfter;
  };

  grantsJson = pkgs.writeText "grants.json" (builtins.toJSON {
    schema = "kailash.grants.v1";
    grants = lib.mapAttrs mintGrant cfg.holders;
  });

  # The checker: kai-grant check <holder> <action> [<tool-id>]. Exit 0
  # allow — exit 1 deny; every decision logs one JSON line. Pure python
  # + pyyaml for the manifest scope resolution.
  kaiGrant = pkgs.runCommand "kai-grant"
    {
      nativeBuildInputs = with pkgs; [ makeBinaryWrapper ];
      passthru.grantsJson = grantsJson;
      meta.mainProgram = "kai-grant";
    }
    ''
      mkdir -p "$out/bin"
      makeWrapper "${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python" \
        "$out/bin/kai-grant" \
        --add-flags "${./kai-grant-cli.py}"
    '';

  # The grant env baked into every kailash-mcp the host installs: the
  # minted file + the default action log. Applied by RE-wrapping the
  # packages-overlay kailash-mcp derivation (the overlay's own wrapper
  # bakes the manifest paths; this re-wrap adds the grant truth on top
  # — the host's single source of the grant state).
  grantWrappedMcp = pk: pk.kailash-mcp.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + "\n" + ''
      wrapProgram "$(command -v kailash-mcp || echo $out/bin/kailash-mcp)" \
        --prefix KAILASH_GRANTS : ${grantsJson} \
        --prefix KAILASH_GRANT_LOG : /var/log/kailash/grants.log
    '';
  });
in
{
  options.kailash.agentGrants = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Capability-grants posture switch (KA-25 v1). Default OFF: the
        deny-by-default floor is no grants file, no checker on PATH —
        unsupervised agents keep exactly the read-only surface.
      '';
    };

    holders = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          categories = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Grant-scoped category ids (the census slugs —
              o-07-agent-mcp-operability). A grant-scoped action on a
              manifest row whose PRIMARY category is not here is denied
              unless the row id is in `tools`.'';
          };
          tools = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''Explicitly named tool ids beyond the scope.'';
          };
          allowExp = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether the grant covers safety.level exp rows. NEVER a
              gate bypass: exp execution ALSO requires the §11.2
              double-key (kailash.labMode + KAILASH_LAB_MODE) — the
              gate wraps the binary regardless of any grant.'';
          };
          allowServiceStart = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether the holder may start grant-scoped services (the
              no-auto-start audit still binds — the audit fixture
              proves a pre-set lab key is a violation per ko#145).'';
          };
          readOnlyOnly = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Unsupervised-agents posture — true keeps the holder to
              list/search/read (the read-only MCP tools + CLI commands)
              EVEN inside its window; mint one purely as an auditable
              marker. Write/exec shapes require readOnlyOnly = false.'';
          };
          notBefore = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''ISO-8601 window start (optional).'';
          };
          notAfter = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              ISO-8601 window end — the SHORT-LIVED half. An exec- or
              service-capable holder WITHOUT notAfter fails the module
              assertion (no unlimited-window grant at v1).'';
          };
        };
      });
      default = { };
      description = ''
        The minted holders. Keys are holder names (the session/agent
        identity); every field defaults to the deny side.
      '';
    };

    grantsReport = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = ''
        The minted grants.json store path — consumed by kai-grant and
        baked into the kailash-mcp wrapper (one grant truth: the OS
        option tree, the checker and the MCP server).
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # SHORT-LIVED contract: an exec/service-capable holder must
      # declare notAfter (assert at eval — the grant mint refuses an
      # unlimited window; read-only holders may omit it).
      assertions = lib.mapAttrsToList (name: g: {
        assertion = (g.readOnlyOnly && !g.allowServiceStart) || g.notAfter != null;
        message = "kailash.agentGrants.holders.${name}: the holder grants non-read scope but carries no notAfter — capability grants v1 are short-lived (plan §11.2); mint an expiry window.";
      }) cfg.holders;

      kailash.agentGrants.grantsReport = grantsJson;

      environment.systemPackages = [ kaiGrant ];

      # the state committed into the closure — the auditable grant truth
      environment.etc."kailash/grants/grants.json".source = grantsJson;

      # the action log lives on the mutable host (append-only surface)
      systemd.tmpfiles.rules = [
        "f /var/log/kailash/grants.log 0640 root wheel - -"
      ];
    }

    # bake the minted grant truth into the kailash-mcp wrapper when the
    # packages overlay is composed (grantWrappedMcp resolves null
    # without the overlay; the MCP face keeps its derivation-baked
    # manifest env and gains the grants env)
    (lib.mkIf (pkgs ? kailash-mcp) {
      environment.systemPackages = [ (grantWrappedMcp pkgs) ];
    })
  ]);
}
