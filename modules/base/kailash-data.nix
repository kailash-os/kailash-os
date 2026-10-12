# CORE substrate — kailash.data.* DATA-PACK composition namespace
# (KA-29, kailash-os#29; plan §3.2 C-5 + §8.1 data-pack posture).
#
# The landed kailash-data.* DATA pack derivations live in
# kailash-packages (pkgs/seclists — the wordlists-mega corpus, and
# pkgs/pw-packs — the small rockyou.txt slice; the KA-29 lane). DATA
# packs NEVER ride a default profile or ISO by construction (plan §8.1:
# "the wordlist packs are excluded from every default ISO by
# construction"; §3.2 C-5: seclists ~100 MB behind
# kailash-data.wordlists-mega — toggle vs data-ISO decision logged,
# DEFAULT TOGGLE). This module declares the typed per-pack opt-in
# options and mounts ONLY the flipped packs onto environment.systemPackages.
# Everything defaults FALSE: the CORE floor (kailash-minimal) and every
# built-in profile stay pack-free until an operator flips a lab-host
# key (§11.2 posture; per-file corpus licences are NOT established —
# the derivation headers + manifest rows carry the record).
#
# WHY A kailash.data.* NAMESPACE BESIDE THE §4.5 CATEGORY TREE
# (recorded per the c-07 DECISION block's revisit condition): data
# packs are not census categories — the manifest routes them as
# status:data rows the generator excludes from category install sets
# (generated/manifest-ids.json excluded lists), so a category enable
# would claim census membership the manifest does not carry. The §3.2
# C-7 sdr-tools carve-out is the opt-in data-pack precedent (§4.1);
# the wordlist packs ride the same posture with the namespace as the
# toggle surface the issue's "default toggle" decision names.
#
# BINDING SHAPE (§4.5 overlay-guard, the KA-13.2 composition rule):
# manifest row id == pack dir id == overlay auto-call attr
# (pkgs/auto-call.nix); the binding is a null-guarded id lookup that
# composes at ANY packages pin. Resolution facts at this pin, probed
# (KA-29 lane, nixpkgs 8c3cede7 + packages pin ef70ec4b — verified via
# nix eval, never assumed):
#   * wordlistsMega → `pkgs."seclists"`: the overlay-composed set
#     SHADOWS nixpkgs, so at the pre-bump pin this resolves to the
#     NATIVE nixpkgs seclists attr (2026.1, the SAME danielmiessler
#     tarball — sha256-S1C+/gX3mvCC9OVxzCO6PrzbvxCz5mTWEXrBqzSuKps=
#     probed equal on both attrs; layout share/wordlists) and to the
#     KA-29 overlay pack after the packages lock bump (layout
#     share/kailash/data, the recorded licence header). The option's
#     contract is the manifest row id, not the layout: both resolve
#     the same corpus.
#   * pwPacks → `pkgs."pw-packs"`: natively ABSENT in nixpkgs at this
#     pin (probed ___ABSENT___ — nixpkgs' `rockyou` attr is a
#     DIFFERENT id and is deliberately NOT bound), so a pre-bump pin
#     composes it as NULL and the pack drops (the §4.5 overlay-guard
#     rule; it returns with the pin — the watched-RED leg names it).
# The binding is deliberately the plain id shadow lookup: no per-pin
# special cases in code (the derivation lane owns the pack surface;
# this module owns the opt-in switch).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.data;

  # manifest row id → overlay auto-call attr, null-guarded (§4.5).
  packFor = {
    wordlistsMega = pkgs."seclists" or null;
    pwPacks = pkgs."pw-packs" or null;
  };
in
{
  options.kailash.data = {
    # §3.2 C-5: "seclists ~100 MB behind kailash-data.wordlists-mega";
    # the manifest row is seclists, the pack id the overlay auto-calls.
    wordlistsMega = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Mount the kailash-data.wordlists-mega DATA pack (the SecLists
        corpus, manifest row seclists) onto systemPackages. OPT-IN,
        default FALSE: the ~1.8 GB corpus never rides a default profile
        or ISO (§8.1, the §3.2 C-5 toggle's logged default). The pack
        derivation's header records the licence posture (repo MIT;
        per-file corpus content NOT established).
      '';
    };

    pwPacks = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Mount the pw-packs DATA pack (rockyou.txt, manifest row
        pw-packs) onto systemPackages. OPT-IN, default FALSE: data
        packs never ride a default profile or ISO (§8.1); the
        breach-list content licence beyond the repo MIT licence is NOT
        established (the derivation header + manifest row carry it).
      '';
    };

    # READ-ONLY resolved-pack passthrough (module-internal): the
    # derivation each flip binds (null while the packages pin lacks
    # the overlay attr). Checks + tooling read it; hosts never set it
    # (readOnly — flips go through the enable options above).
    packPaths = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.package);
      readOnly = true;
      description = ''
        The RESOLVED DATA-pack derivations behind each kailash.data.*
        flip (null when the composed packages pin predates the pack —
        the §4.5 overlay-guard shape). Set only by this module.
      '';
    };
  };

  config = {
    # Typed pass-through of the RESOLVED pack derivations (the pins leg
    # reads packPaths.wordlistsMega.pname/version to prove the corpus
    # identity through the composed overlay; hosts and tooling can
    # point at the corpus path directly). Null when the pin lacks the
    # attr (the §4.5 overlay-guard shape); readOnly — hosts flip the
    # enable options, never the resolved set.
    kailash.data.packPaths = {
      wordlistsMega = packFor.wordlistsMega;
      pwPacks = packFor.pwPacks;
    };

    # The opt-in mounts — one append per flipped pack, null-guarded so
    # a pin predating the pack composes the pack as a no-op drop until
    # the packages lock bump carries it (never an eval failure).
    environment.systemPackages =
      (lib.optionals (cfg.wordlistsMega && packFor.wordlistsMega != null)
        [ packFor.wordlistsMega ])
      ++ (lib.optionals (cfg.pwPacks && packFor.pwPacks != null)
        [ packFor.pwPacks ]);
  };
}
