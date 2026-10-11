# Safety defaults (KA-18.1, os#92; plan §11.2) — the lab-mode double-key gate.
#
# Every tool the packages manifest tags safety:exp installs only through a
# generated gate wrapper and refuses to execute unless BOTH keys are set:
#
#   * host key   — the NixOS option `kailash.labMode` (default false), baked
#                  into the wrapper at build time;
#   * shell key  — KAILASH_LAB_MODE=1 on the individual invocation.
#
# The exp tool id list flows from the packages manifest (kailashPackages +
# "/manifest/tools.yaml") and any additional host-declared manifest surfaces
# via `kailash.safety.manifests` — scanned at eval, never hand-copied.
# `kailash.safety.extraTools` is the wiring surface hosts declare exp-class
# packages through, and the hook point for KA-19.1's packages-side wrapper
# generator (os#94).
#
# RED stub: option surface only — `manifestExpIds` reports empty (the scan
# lands with GREEN) and nothing is wrapped. The watched RED is the trio of
# safety-exp-* checks in flake.nix: the synthetic-fixture exp tool is
# declared but wraps nothing (gate legs) and the parity requirement is
# uncovered (validator leg).
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
        synthetic manifest. Scan lands with the GREEN commit.
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
        of kailash.safety.extraTools. The exp-wrap coverage gate requires
        declared exp packages to be fully wrapped.
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
  };

  config = {
    # RED stub semantics: the manifest scan reports nothing and no gate
    # exists — extraTools install BARE (pre-gate behaviour) so the watched
    # RED is the honest "gate absent: the exp tool ran" observation. The
    # GREEN commit replaces this with the gate wrappers.
    kailash.safety.manifestExpIds = [ ];
    kailash.safety.expToolIds = [ ];
    kailash.safety.wrappedPackages = config.kailash.safety.extraTools;
    # RED stub: pre-gate behaviour — the exp-class packages land on the
    # system PATH bare. GREEN replaces this passthrough with gate wrappers
    # (same environment line, wrapped derivations).
    environment.systemPackages = config.kailash.safety.wrappedPackages;
    kailash.safety.wrappedIds = [ ];
    kailash.safety.wrappedReport = "/etc/kailash/safety/wrapped-exp-tools.json";
  };
}
