# Layer CLASSIC — C-4 Database Assessment (KA-06.2, ko#97; spec §3.5).
#
# The second-four category module off the KA-06.1 exemplar: same shape —
# the typed spine (modules/base/layer-tree.nix) owns enable/packages on
# kailash.layers.classic.categories.c-04; this module mounts the install
# set config-only, consuming generated/manifest-ids.json through its
# reviewed binding table; mkIf enable installs (opt-in by default).
#
# Binding table (probed at nixpkgs 8c3ced + packages pin 7374e7a — never
# assumed id==attr):
#   * psql → pkgs.postgresql_16 (the manifest id is the psql CLI, which
#     ships inside the PostgreSQL server package; the client binaries
#     ride the server derivation's outPath bin/);
#   * redis-cli → pkgs.redis (redis-cli ships inside the redis server
#     package);
#   * mssql-cli → the packages overlay (bespoke, manifest
#     packaging.derivation pkgs/mssql-cli).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-04;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-04-database-assessment.installable;

  attrFor = id:
    {
      "psql" = pkgs.postgresql_16 or null;
      "redis-cli" = pkgs.redis or null;
    }."${id}" or (pkgs."${id}" or null);

  installSet = lib.filter (p: p != null) (map attrFor ids);
in
{
  config = {
    # The manifest-driven install set (all 7 c-04 rows bind at this pin).
    kailash.layers.classic.categories.c-04.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
