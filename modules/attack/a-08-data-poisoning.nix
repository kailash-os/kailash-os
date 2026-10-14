# Layer ATTACK — A-8 Data Poisoning (KA-23, kailash-os#23; os#210 purge
# update 2026-10-14). The category module — spine-owned typed surface
# (enable + packages declared by modules/base/layer-tree.nix),
# `mkIf enable` installs (opt-in by default).
#
# POST-PURGE STATE: four of the six pre-purge A-8 poisoning-workbench
# rows were phantom-upstream — their claimed kailash-os repos never
# existed; the os#210 audit removed them. One further pre-purge row (a
# data pack) rode a-03's secondary surface and was removed there. The
# category keeps ONE real row (trojai-toolkit, upstream trojai/trojai)
# as a derivation-pending bespoke install surface. Aspirational names
# live in the registry (kailash-os#210) and return via the rebuild
# contract (build for real, verified upstream, then gate + ledger).
#
# BINDING TABLE: the trojai row keeps the bare guard (its overlay
# derivation is pending — pkgs/trojai-toolkit has not landed in
# kailash-packages); it resolves null and drops until its lane lands.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.attack.categories.a-08;

  ledger = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.a-08-data-poisoning;

  # Bare guard per the binding note above.
  attrFor = id: pkgs."${id}" or null;

  installSet = lib.filter (p: p != null) (map attrFor ledger.installable);
in
{
  config = {
    # The manifest-driven install set (EMPTY at this pin: the trojai
    # row's derivation is overlay-pending).
    kailash.layers.attack.categories.a-08.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
