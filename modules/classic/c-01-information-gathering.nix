# Layer CLASSIC — C-1 Information Gathering (KA-06.1, ko#96; plan §4.5).
#
# The §4.5 EXEMPLAR category module — the shape every later category
# module copies. The composition is config-only data (the KA-09.1 typed
# spine owns the enable/packages baseline members on
# kailash.layers.classic.categories.c-01):
#
#   * the manifest-generated id list flows from
#     generated/manifest-ids.json (categories.c-01.*.installable) —
#     produced by tools/gen-categories.py + `make gen-categories`, never
#     hand-maintained; the flake's c-01-exemplar leg verifies it against
#     the PINNED packages manifest and fails with drift lines on decay;
#   * the reviewed binding table maps id → pkgs attr at the pinned
#     packages rev (probed per entry, never assumed id==attr): a
#     non-bare attr is a NAMED entry with the pin-probe note, unknown
#     attrs fall through to the bare `pkgs."${id}" or null` guard;
#   * `mkIf enable` installs — opt-in by default, the §4.5 posture.
#
# GREEN (this commit): the exemplar consumes the generated artifact —
# the RED stub (installs NOTHING) is replaced by the 36-entry install
# set; the SAME check assertions (non-empty set, parity) pass through
# the SAME eval.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-01;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-01-information-gathering.installable;

  # The binding table: the two nixpkgs attrs whose case-normalized names
  # differ from the manifest id (probed at nixpkgs 8c3ced + packages pin
  # 7374e7a); everything else binds bare. A manifest-bespoke id whose
  # derivation has not landed in kailash-packages pkgs/ yet (sublist3r,
  # spiderfoot at this pin) falls to the bare guard, resolves null and
  # drops from the install set WITHOUT breaking eval — the row returns
  # when its derivation lane lands.
  attrFor = id:
    {
      "the-harvester" = pkgs.theharvester or null;
      "maltego-community" = pkgs.maltego or null;
    }."${id}" or (pkgs."${id}" or null);

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (36 of the 38 manifest rows at this
    # pin; the two pending bespoke derivations drop via the guard).
    kailash.layers.classic.categories.c-01.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default. Every row is a manifest safe-level
    # tool; exp-class rows are absent from the tree by construction
    # (the lab-mode gate owns that surface).
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
