# Layer CLASSIC — C-5 Password & Offline-Credential (KA-07.2, ko#100; §4.5).
#
# DESIGN — the ko#100 pick:
#   * C-5 installs the manifest's offline-credential tool set: the
#     hash-cracking flagship pair (hashcat, the John suite incl. the
#     johnny GUI), hash-type identification (hashid, hash-identifier),
#     and the word-mangling/gen helpers. Online brute-forcing against
#     live services stays OUT (§3.7; the manifest c-05 notes) — the
#     census carries no live-service cracker in this category.
#   * wordlists are ABSENT from this module's install set. The manifest's
#     single data row (seclists, status:data) is excluded by the
#     generator (generated/manifest-ids.json categories.c-05.excluded —
#     "category modules never install data rows") and rides the opt-in
#     kailash-data.wordlists-mega pack (plan D7; manifest categories.yaml
#     c-05 notes: "wordlists ride the opt-in kailash-data.wordlists-mega
#     pack (KA-07.2)"). The pack is a data DERIVATION in kailash-packages
#     — it does NOT land in this OS repo; when the pack grows, its
#     opt-in mounting attaches on the data-pack lane, not by adding
#     rows to a category module.
#
# GREEN (this commit): the RED stub (installs NOTHING) is replaced by
# the manifest-generated install set — the SAME c-05-options check
# assertions (non-empty set, hashcat present) pass through the SAME
# eval.
#
# Binding table (probed at nixpkgs 8c3ced + packages pin 7374e7a — never
# assumed id==attr): all NINE native rows bind bare-top with
# pname == id and meta.broken false on BOTH systems (hashcat 7.1.2,
# john 1.9.0-Jumbo-1, johnny 2.2, ophcrack 3.8.0, crunch 3.6, cewl
# 6.2.1, hashid, hash-identifier 1.2, rsmangler) — no non-bare attrs,
# no python-module detours, no carriers at this pin. The FIVE
# manifest-bespoke rows (maskgen, policygen, statsgen, bopscrk, twofi)
# have not landed in kailash-packages pkgs/ at this pin — they fall to
# the bare guard, resolve null and drop WITHOUT breaking eval (the
# exemplar's overlay-guard rule; dnsrecon/subfinder controls proved the
# probe reads the composed overlay). Their rows return when the packaging
# lane lands them.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-05;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-05-password-offline-credential.installable;

  # Every native row binds bare at this pin (the header's probe table) —
  # no named non-bare entries. Overlay-pending bespoke ids resolve null
  # through the guard and drop (they return with their derivations).
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.unique
    (lib.filter
      (p: p != null && !(p.meta.broken or false))
      (map attrFor ids));

in
{
  config = {
    # The manifest-driven install set (9 of the 14 installable ids at
    # this pin: the five bespoke rows — maskgen, policygen, statsgen,
    # bopscrk, twofi — are overlay-pending drops; seclists sits in the
    # generator's excluded list, the data-pack lane).
    kailash.layers.classic.categories.c-05.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default. Every row is a manifest safe-level tool;
    # exp-class rows are absent from the tree by construction (the
    # lab-mode gate owns that surface).
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
