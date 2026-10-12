# Layer ATTACK — A-2 Prompt Injection & Jailbreaks (KA-13.1, ko#103;
# plan §4.5, §3.3).
#
# The §4.5 category module — the same mount as the exemplar
# modules/classic/c-01-information-gathering.nix and the sibling
# a-01 module: spine-owned typed surface (enable + packages live on
# kailash.layers.attack.categories.a-02, declared by
# modules/base/layer-tree.nix), config-only install-set mount,
# `mkIf enable` installs (opt-in by default).
#
# SAFETY (§11.2 posture, recorded per row from the manifest at the
# packages pin 7374e7a): every installable row here is
# safety.level "requires-target" (garak, promptfoo, pyrit, inj3ct-llm)
# — target-required ATTACK rows: package-list surfaces, NOT exp-gated
# (only `safety.level == "exp"` rows ride the lab-mode gate). No a-02
# row is exp at this pin.
#
# DATA rows never install (the generator's excluded ledger in
# generated/manifest-ids.json records them): llm-red-team-col,
# jailbreak-payloads, libertas-prompts, llm-jailbreak-bench are
# status:"data" packs — opt-in data-packs, never on default profiles;
# their land rides ko#104 (KA-13.2's payload/data wave).
#
# Binding table (probed at nixpkgs 8c3ced + packages pin 7374e7a —
# never assumed id==attr): garak, promptfoo, pyrit resolve through the
# kailash-packages OVERLAY at this pin (the three flagship derivations
# pkgs/garak, pkgs/promptfoo, pkgs/pyrit — probed: real pnames, not
# broken, e.g. garak 0.17.1.pre1-unstable-2026-10-09); inj3ct-llm is a
# manifest-BESPOKE row whose derivation has NOT landed at this pin —
# bare-guard drop (named above), returns when its lane lands.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-02;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-02-prompt-injection-jailbreaks.installable;

  # No non-bare bindings at this pin: the three overlay flagships and the
  # pending inj3ct-llm all bind the bare guard (the overlay's attrs ARE
  # the ids — callPackage auto-call, §5.5).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (3 of the 4 rows at this pin:
    # garak + promptfoo + pyrit through the overlay; inj3ct-llm is the
    # overlay-pending bespoke drop).
    kailash.layers.attack.categories.a-02.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
