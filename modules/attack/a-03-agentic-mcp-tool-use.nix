# Layer ATTACK — A-3 Agentic / MCP tool-use (KA-22, kailash-os#22; plan
# §4.5, §9 Phase 5). The §4.5 category module — the same config-only
# mount as the a-01/a-02 exemplars: spine-owned typed surface (enable +
# packages live on kailash.layers.attack.categories.a-03, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default — nothing on PATH until the category switch is ON).
#
# SAFETY (§11.2 posture; os#210 purge update 2026-10-14): three of the
# row families this module recorded pre-purge were phantom-upstream
# (mcp-unsafe-deser-probe — exp; poisoned-skill-pack — the data row;
# langchain-vuln-hunter + llm-agent-fuzzer installable-bespoke): their
# claimed kailash-os upstream repos were never created, the os#210
# audit removed them, registry: kailash-os#210. mcpoison keeps its
# exp-class routing (real upstream pulkitb124/mcpoison; its overlay
# derivation is pending). The five installable rows post-merge:
# mcp-scan, mcp-guardian, mcp-remote (lanes landed in kailash-packages
# pkgs/), agent-dojo (lane landed), plus nothing else —
# package-list surfaces.
#
# BINDING TABLE (probed at nixpkgs 8c3ced + packages pin): mcp-scan,
# mcp-guardian, mcp-remote, agent-dojo bind their landed
# kailash-packages derivations (the pkgs/ dirs exist post-KA-22);
# their install rides the bare auto-call surface. mcp-inspector — the
# §3.1 attack-chain primary the census names for this category — is an
# o-07 manifest row (o-07-agent-mcp-operability; this category carries
# it as a SECONDARY): it composes through the OPS surface, never here
# (the §4.5 no-duplicate-install rule).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-03;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-03-agentic-mcp-tool-use;

  # Post-merge the four landed derivations bind (their overlay attrs
  # are the ids per §5.5 auto-call); no bare-guard drops remain.
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (the five real rows bind through
    # the landed overlay derivations post-KA-22; phantom rows removed
    # per os#210).
    kailash.layers.attack.categories.a-03.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
