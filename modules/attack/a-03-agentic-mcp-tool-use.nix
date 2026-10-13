# Layer ATTACK — A-3 Agentic / MCP tool-use (KA-22, kailash-os#22; plan
# §4.5, §9 Phase 5). The §4.5 category module — the same config-only
# mount as the a-01/a-02 exemplars: spine-owned typed surface (enable +
# packages live on kailash.layers.attack.categories.a-03, declared by
# modules/base/layer-tree.nix), `mkIf enable` installs (opt-in by
# default — nothing on PATH until the category switch is ON).
#
# SAFETY (§11.2 posture, read from the generator's ledger — the manifest
# is the single home of the facts; KA-22 extended gen-categories.py to
# carry the exp ledger):
#   * the two exp rows (mcp-unsafe-deser-probe, mcpoison) ride the
#     ledger's `exp` key — NEVER `installable`, never a package-list
#     surface (the §11.2 double-key gate owns exp routing);
#   * poisoned-skill-pack is the status:data row (ledger `excluded`,
#     D7 — opt-in data-pack, never installed by category modules);
#   * the six installable rows are package-list surfaces.
#
# BINDING TABLE (probed at nixpkgs 8c3ced + packages pin ef70ec4 — never
# assumed id==attr): every one of the six installable rows is a
# manifest-BESPOKE row whose kailash-packages derivation has NOT landed
# at this pin (no pkgs/mcp-scan, mcp-guardian, mcp-remote, agent-dojo,
# langchain-vuln-hunter, llm-agent-fuzzer dirs at ef70ec4) — they fall
# to the bare guard, resolve null and DROP (named above) without
# breaking eval; the empty install set is CORRECT at this pin (the
# KA-24 d-01 all-pending posture) and each row returns when its
# derivation lane lands in kailash-packages pkgs/. mcp-inspector — the
# §3.1 attack-chain primary the census names for this category — is an
# o-07 manifest row (o-07-agent-mcp-operability; this category carries
# it as a SECONDARY): it composes through the OPS surface, never here
# (the §4.5 no-duplicate-install rule).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-03;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-03-agentic-mcp-tool-use;

  # No non-bare bindings at this pin: all six installable rows keep the
  # bare guard (the overlay attrs are the ids per §5.5 auto-call — the
  # named drops resolve null here and return with their lanes).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (0 of the 6 rows bind at this pin —
    # all bespoke-overlay-pending, named above).
    kailash.layers.attack.categories.a-03.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
