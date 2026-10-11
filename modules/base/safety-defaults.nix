# Safety defaults (KA-18.1, os#92; plan §11.2) — the lab-mode double-key gate.
#
# Every tool the packages manifest tags safety:exp installs only through a
# generated gate wrapper and refuses to execute unless BOTH keys are set:
#
#   * host key   — the NixOS option `kailash.labMode` (default false), baked
#                  into the wrapper at build time;
#   * shell key  — KAILASH_LAB_MODE=1 on the individual invocation.
#
# The exp tool id list flows from the packages manifest
# (kailash-packages.outPath + "/manifest/tools.yaml") and any additional
# host-declared manifest surfaces via `kailash.safety.manifests` — scanned
# at eval, never hand-copied. `kailash.safety.extraTools` is the wiring
# surface hosts declare exp-class packages through, and the hook point for
# KA-19.1's packages-side wrapper generator (os#94).
{ config, lib, pkgs, ... }:

{
  options = {
    kailash.labMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Host-side key of the lab-mode double-key gate. All exp-tagged
        tooling refuses to run unless this option AND the per-invocation
        KAILASH_LAB_MODE=1 shell opt-in are both explicitly set
        (double-key, no default-on — plan §11.2).
      '';
    };

    kailash.safety.manifests = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        tools.yaml manifest surfaces scanned for safety:exp ids. The host
        wires the pinned packages manifest here (through the OS flake
        input, never a hand-copy); the safety-fixture checks add their
        synthetic manifest.
      '';
    };

    kailash.safety.extraTools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Host-declared safety:exp-class packages. The module wraps every one
        into the lab-mode gate and installs ONLY the wrapped form — the
        bare derivation never reaches the system PATH. Wiring surface for
        hosts and for KA-19.1's manifest-driven wrapper generator (os#94).
      '';
    };

    kailash.safety.manifestExpIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Tool ids the declared manifests tag safety:exp, scanned at eval —
        never a hand-copy. Cross-checked against an independent PyYAML
        parse by the exp-wrap parity check in the root flake.
      '';
    };

    kailash.safety.expToolIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Every exp-class id this host knows: the manifest scan plus the ids
        of kailash.safety.extraTools.
      '';
    };

    kailash.safety.wrappedPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      readOnly = true;
      description = ''
        The lab-gated package derivations: one gate wrapper per
        kailash.safety.extraTools entry. Also what category-module wiring
        (Wave-5/6) installs for exp tools.
      '';
    };

    kailash.safety.wrappedIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Tool ids of kailash.safety.wrappedPackages. The exp-wrap parity
        validator requires every declared exp-package id to appear here.
      '';
    };

    kailash.safety.wrappedReport = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Absolute path of the per-id wrap report committed into the host
        closure (/etc/kailash/safety/wrapped-exp-tools.json) — the state
        the exp-wrap parity validator consumes from a sandbox.
      '';
    };

    kailash.safety.wrappedReportFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = ''
        The store path of the wrap report file — what the flake check
        feeds to the validator.
      '';
    };
  };

  config =
    let
      sc = config.kailash.safety;
      hostLabMode = config.kailash.labMode;

      # A tool's manifest-side id: the derivation name minus any version
      # suffix (parseDrvName's name component). The fixture tool's
      # derivation name is exactly its manifest id; the Wave-5 wiring binds
      # real tools' id↔derivation pairs through the manifest rows.
      toolIdOf = p: (builtins.parseDrvName (p.name or "")).name;
      mainProgOf = p: p.meta.mainProgram or (toolIdOf p);

      # The manifest scanner: extracts safety.level == exp ids from the
      # declared tools.yaml surfaces at eval — never a hand-copy. Covers
      # both `- id: <tool>` rows and keyed `- <tool>:` rows; the level row
      # closes the pending entry. Same row-shape contract as
      # tools/safety-exp-wrap.py (the parity leg cross-checks with an
      # independent PyYAML parse).
      scanToolsYaml = file:
        (builtins.foldl'
          (state: line:
            let
              idRow = lib.match " *- id: *([A-Za-z0-9._-]*)" line;
              keyedRow = lib.match " *- ([A-Za-z0-9._-]*):.*" line;
              levelRow = lib.match " *level: *([A-Za-z0-9._-]*).*" line;
            in
            if line == "" || lib.match " *#.*" line != null then state
            else if idRow != null then { ids = state.ids; pending = builtins.head idRow; }
            else if keyedRow != null then { ids = state.ids; pending = builtins.head keyedRow; }
            else if levelRow != null && state.pending != null then
              (
                if builtins.head levelRow == "exp"
                then { ids = state.ids ++ [ state.pending ]; pending = null; }
                else { ids = state.ids; pending = null; }
              )
            else state
          )
          { ids = [ ]; pending = null; }
          (lib.splitString "\n" (builtins.readFile file))).ids;

      # The gate wrapper: one derivation per exp tool. Each executable in
      # the inner package's bin/ is replaced by a gate script enforcing the
      # double-key gate at run time:
      #   * shell key — KAILASH_LAB_MODE=1 must be set for the invocation;
      #   * host key  — kailash.labMode, baked into the script at build
      #     time; a lab-off host's gated wrapper refuses even with the
      #     shell key set.
      # The refusal names BOTH keys so the acceptance run can prove them
      # (the gate-run check greps both). Only bin/ executables are gated;
      # libexec surfacing is a Wave-5 wiring concern alongside the module
      # contract's consumers.
      gateFor = p:
        let
          progName = mainProgOf p;
          innerPkg = p;
        in
        pkgs.runCommand "${toolIdOf p}-lab-gated"
          {
            passthru = { inherit progName; };
            meta.mainProgram = progName;
          } ''
          mkdir -p "$out/bin"
          for srcbin in ${innerPkg}/bin/*; do
            name="$(basename "$srcbin")"
            if [ -f "$srcbin" ] && [ -x "$srcbin" ]; then
              {
                printf '#!%s\n' "${pkgs.bash}/bin/sh"
                printf 'if [ "$KAILASH_LAB_MODE" != "1" ] || [ "%s" != "1" ]; then\n' "${if hostLabMode then "1" else "0"}"
                printf '  echo "kailash lab-mode gate: [%s] is safety:exp tooling and refuses to run.\n" >&2\n' "$name"
                printf '  echo "  host key:  set kailash.labMode = true in the host configuration\n" >&2\n'
                printf '  echo "  shell key: KAILASH_LAB_MODE=1 on this individual invocation\n" >&2\n'
                printf '  echo "  both keys are required (docs/responsible-use.md).\n" >&2\n'
                printf '  exit 126\n'
                printf 'fi\n'
                printf 'exec "%s/bin/%s" "$@"\n' "${innerPkg}" "$name"
              } > "$out/bin/$name"
              chmod +x "$out/bin/$name"
            fi
          done
        '';
    in
    {
      # The manifest scan: exp ids from every declared manifest surface,
      # deduplicated in manifest order.
      kailash.safety.manifestExpIds = lib.unique (
        lib.concatMap scanToolsYaml sc.manifests
      );

      kailash.safety.expToolIds = lib.unique (
        sc.manifestExpIds
        ++ map toolIdOf sc.extraTools
      );

      # The gated install: ONLY the gate wrappers go on the system PATH —
      # the bare exp derivations never do.
      kailash.safety.wrappedPackages = map gateFor sc.extraTools;
      kailash.safety.wrappedIds = map toolIdOf sc.extraTools;

      environment.systemPackages = config.kailash.safety.wrappedPackages;

      # The wrap report: committed into the closure at
      # /etc/kailash/safety/wrapped-exp-tools.json — the exp-wrap parity
      # validator's input (world-readable state of the host's gate).
      environment.etc."kailash/safety/wrapped-exp-tools.json".text =
        builtins.toJSON {
          wrapped = map
            (p: {
              id = toolIdOf p;
              program = mainProgOf p;
              package = toString (gateFor p);
            })
            sc.extraTools;
        };

      kailash.safety.wrappedReport =
        "/etc/kailash/safety/wrapped-exp-tools.json";
      kailash.safety.wrappedReportFile =
        config.environment.etc."kailash/safety/wrapped-exp-tools.json".source;
    };
}
