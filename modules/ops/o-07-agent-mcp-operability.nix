# Layer OPS — O-7 Agent & MCP Operability (KA-25, os#25; plan §3.5,
# §9 Phase 3, §11.2). The §4.5 category module — config-only mount on
# the typed spine (modules/base/layer-tree.nix declares enable +
# packages at kailash.layers.ops.categories.o-07), the D-layer shape
# (KA-24 exemplar modules/defence/d-01-runtime-defence.nix).
#
# ROUTING CONTRACT (the manifest rows are the routing record; the
# manifest is the single home of the facts — recorded per row from the
# pinned packages manifest):
#
#   * SAFETY — SEVEN of the eight o-07 rows are safety.level "exp"
#     (hexstrike-ai, mcp-kali-server, malicious-mcp-poc, insecure-mcp-lab,
#     kailash-mcp, kailash-container, headless-agent). §11.2: exp rows
#     NEVER enter an install set — the lab-mode double-key gate owns
#     exp routing. The landed bespoke exp faces (kailash-mcp,
#     hexstrike-ai, mcp-kali-server — from the packages overlay at this
#     pin) are wired THROUGH kailash.safety.extraTools in this module:
#     the gate wraps each into a <id>-lab-gated derivation and installs
#     ONLY the wrapped form; the bare derivation never reaches PATH.
#     The capability-grants face (kailash.agentGrants — KA-25 grants v1,
#     modules/base/agent-grants.nix) adds the human-minted grant scope
#     ON TOP; a grant never bypasses the gate.
#   * mcp-inspector is the ONE safe row (dogfood duty — the CI loop
#     runs the A-3 scanner suite against kailash-mcp): resolves into
#     the ordinary §4.5 package-list surface (mkIf enable).
#   * malicious-mcp-poc + insecure-mcp-lab are DATA rows (opt-in lab
#     packs, D7) — data rows never ride a category install set; their
#     fetchable upstreams do not exist at this pin (the manifest rows
#     record the kailash-os org repos; the data-pack lanes land them).
#   * kailash-container + headless-agent are manifest-bespoke rows
#     WITHOUT landed derivations (first-party DELIVERABLES: the image
#     matrix's boot-to-agent target and the container image — the
#     images wave lands them; ko#173 records the deliverable-shape
#     decision). They stay the named drops below — overlay-pending,
#     resolving null without breaking eval (the D-layer precedent),
#     each returning when its lane lands.
#
# BINDING TABLE (probed at the OS pin nixpkgs 8c3cede7 + packages
# overlay ef70ec4 — never assumed id == attr):
#   * kailash-mcp      → packages-overlay row (pkgs/kailash-mcp): the
#     first-party MCP server; grant env baked by agent-grants when the
#     posture is on;
#   * hexstrike-ai     → packages-overlay row (pkgs/hexstrike-ai, Shape
#     1, eager import chain only — angr/pwntools are the shells-out
#     tool set, not module-level imports);
#   * mcp-kali-server  → packages-overlay row (Shape 1, light);
#   * mcp-inspector    → packages-overlay row (buildNpmPackage at the
#     upstream 2.10.1 tag; node >=22.19 satisfied by the pin's nodejs).
#   All four bind at THIS pin with the overlay composed; the two
#   pending deliverables + the two data packs stay named.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.ops.categories.o-07;

  # The overlay's landed O-7 faces at this pin. Bare-guarded per row
  # (the exemplar's return-rule — null at revisions without the overlay
  # or where a derivation moves): the exp faces route through the gate
  # below, the safe face rides the install set.
  overlay = id: pkgs."${id}" or null;

  # Landed bespoke exp faces → the §11.2 gate (kailash.safety.-
  # extraTools wraps each; the wrapped form installs instead).
  expFaces = lib.filter (p: p != null)
    (map overlay [ "hexstrike-ai" "mcp-kali-server" "kailash-mcp" ]);

  # The safe dogfood face → the §4.5 package-list surface.
  safeFaces = lib.filter (p: p != null) (map overlay [ "mcp-inspector" ]);

  installSet = safeFaces;
in
{
  config = lib.mkMerge [
    {
      # The manifest-driven install set (1 of the 6 installable rows at
      # this pin: mcp-inspector — the five exp faces route through the
      # gate, the two data packs and the two pending deliverables stay
      # named drops above).
      kailash.layers.ops.categories.o-07.packages = installSet;

      environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
    }

    # The exp routing: the landed faces ride kailash.safety.extraTools
    # ONLY when the category is enabled — the §4.5 opt-in contract
    # extends to the gate-wrapped surface (no exp tooling on PATH of a
    # host that never enabled O-7 — even wrapped).
    (lib.mkIf cfg.enable {
      kailash.safety.extraTools = expFaces;
    })
  ];
}
