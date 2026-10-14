# Layer ATTACK — A-2 LLM Prompt Injection & Jailbreaking, DATA-PACKS
# composition (KA-13.2, kailash-os#104; spec §8 Phase 4).
#
# This is the SIBLING composition module for a-02: it DECLARES the extra
# typed member `packs` at the same §4.5 option path and appends the
# landed DATA-pack derivations from the packages overlay to the
# category's package list — nothing more. The A-2 category module
# itself (modules/attack/a-02-llm-prompt-injection.nix, KA-13.1) owns
# the category's native install surface and the
# `environment.systemPackages` wiring; this module must NOT re-set
# environment.systemPackages (two modules on one category: appender vs
# installer — re-setting both would double every a-02 entry in the
# composed PATH). Hosts that enable `packs` carry the packs in the
# typed a-02 surface; the category module's install leg ships them with
# the category.
#
# The three a-02 manifest DATA rows post-purge (os#210, 2026-10-14) and
# their honest state at this revision (manifest/tools.yaml at the packages
# pin; the pre-purge fourth data row was a phantom-upstream row — its
# claimed kailash-os repo never existed — REMOVED per the os#210
# decision, registry: kailash-os#210):
#   * jailbreak-payloads  → packaged (packages overlay; sha256-pinned
#     fetchFromGitHub of elder-plinius/L1B3RT4S@64960b78 — repo AGPL-3.0,
#     per-file corpus licences NOT established: opt-in data pack, never
#     a default profile surface);
#   * libertas-prompts    → packaged (SAME upstream pin — the manifest's
#     L1B3RT-4S twins; one upstream, two §5.2 rows, like the
#     one-derivation-many-tags posture);
#   * llm-jailbreak-bench → packaged (JailbreakBench/jailbreakbench at
#     tag v1.0.0, repo MIT; the live behavior corpus rides HuggingFace
#     at harness runtime — the pack is harness + metadata, recorded);
#   * the pre-purge fourth DATA row → NOT packaged AND NO LONGER A
#     MANIFEST ROW: the row was REMOVED by the os#210 phantom purge
#     (2026-10-14) — its claimed kailash-os upstream never existed; the
#     earlier "manifest row stays intact" posture (the kailash-os#104
#     keep-rows precedent) is superseded by the os#210 decision-record.
#     The name waits in the registry (kailash-os#210): a re-derivation
#     may appear only together with a real verified upstream + a fresh
#     manifest row (the flake's a-02-data-packs-pins leg carries the
#     standing no-resurrection guard); this module's pack list reads the
#     same landed set.
#
# Opt-in by default (packs default FALSE per kailash-os#104 + the
# manifest banner's data-pack rule): the packs never ride a default
# profile/ISO — flipping `packs` on is an explicit operator decision on
# a lab host (§11.2 posture; licence uncertainty is the reason).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-02;

  # The landed a-02 data packs (KA-13.2). Resolution follows the §4.5
  # category-module binding shape: manifest id → overlay attr, null on
  # a pin without the attr (the overlay is composed guarded by the OS
  # flake, and the lock bump carries the packs into the pin).
  packIds = [
    "jailbreak-payloads"
    "libertas-prompts"
    "llm-jailbreak-bench"
  ];

  attrFor = id: pkgs."${id}" or null;

  packSet = lib.filter (p: p != null) (map attrFor packIds);
in
{
  # Extra member ONLY (the §4.5 baseline enable/packages live on the
  # spine — modules/base/layer-tree.nix). Same path as the KA-13.1
  # category module's options block: the tree MERGES member declarations
  # across modules at the same id — this composes, never conflicts.
  options.kailash.layers.attack.categories.a-02.packs =
    lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Append the A-2 LLM prompt-injection/jailbreaking DATA packs from
        the packages overlay to this category's package list (KA-13.2,
        kailash-os#104). Default FALSE: the packs are research corpora
        with per-file licence positions recorded in their derivations —
        opt-in only, never on default profiles or ISOs. The A-2 category
        module (KA-13.1) owns the install wiring; this option appends
        to the category surface it ships.
      '';
    };

  config = lib.mkIf (cfg.enable && cfg.packs) {
    # The append itself — the §4.5 composition point. The category's
    # packages option MERGES (append) across the modules that define
    # it, so a KA-13.1 a-02 module and this sibling compose cleanly.
    kailash.layers.attack.categories.a-02.packages = packSet;
  };
}
