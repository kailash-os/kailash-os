# Layer OPS — O-3 Vector Stores & Retrieval (KA-09.1, ko#110).
#
# The §4.5 category-module shape (same contract the Wave-5 items land):
#   options.kailash.layers.ops.categories.o-03 = {
#     enable     — the category switch (off by default; profiles opt in);
#     packages   — the native package list this category installs;
#     backends   — the docker-wrapper store ids (KA-09.2, ko#111): a
#                  virtualisation.oci-containers backend container per id,
#                  riding the VIRTUALISATION substrate (never a nix
#                  package, and never a bare global
#                  virtualisation.docker/podman enable — the container
#                  module manages the substrate at category scope; the
#                  ko#111 Shape-3 contract, §5.4);
#   };
#   config (mkIf enable) installs the packages and stands up the services.
#
# Native ids at this pin (PROBED against the flake's locked nixpkgs
# 8c3cede7ddc26bd659d2d383b5610efbd2c7a16e — never assumed id==attr):
#   * chromadb  — pkgs.chromadb (the CLI package) + services.chromadb;
#     the module's package default is pkgs.python3Packages.chromadb;
#   * qdrant    — pkgs.qdrant + services.qdrant;
#   * pgvector  — postgresql.withPackages (postgresqlPackages.pgvector)
#     wired into services.postgresql.package — the vector index ships as
#     a PostgreSQL EXTENSION, there is no standalone pgvector derivation;
#   * faiss     — pkgs.faiss (similarity-search library);
#   * txtai     — pkgs.python3Packages.txtai (the embeddings DB is a
#     python-module attr at this pin, no top-level attr);
#   * jina-embeddings-cli — pkgs.jina-embeddings-cli, the packages-repo
#     bespoke derivation (manifest pkgs/jina-embeddings-cli/default.nix)
#     riding the overlay the OS flake composes — guarded by `?` so host
#     evaluation stays green at revisions without it.
#
# The GREEN part of this file is the typed spine in
# modules/base/layer-tree.nix: `categories` upgrades from the freeform
# `attrsOf anything` placeholder to a typed submodule-with-freeform,
# exactly the §4.5 contract the Wave-5/6 modules mount at. That change is
# this lane's GREEN; the RED stub that pinned the missing contract is
# this module file's first landing.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kailash.layers.ops.categories.o-03;

  # The docker-wrapper contract (ko#111, §5.4 Shape 3): each backend id
  # stands up ONE virtualisation.oci-containers.backend container, image
  # pinned HERE in the module (pull at service start, never at eval —
  # eval stays sandboxed). NOT nix packages; never a bare global
  # docker/podman enable.
  backendImages = {
    weaviate = "semitechnologies/weaviate:1.39.2";
    milvus = "milvusdb/milvus:v2.6.7";
    elasticsearch = "docker.elastic.co/elasticsearch/elasticsearch:7.17.27";
  };
in

{
  options.kailash.layers.ops.categories.o-03 = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the O-3 Vector Stores and Retrieval category (KA-09.1): the
        native store tooling (chromadb, qdrant, the pgvector-backed
        PostgreSQL, faiss, txtai, jina-embeddings-cli) and, with `backends`,
        the docker-wrapper store containers (KA-09.2).
      '';
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        The O-3 category's install set: the manifest's native rows the
        module installs by default, extendable per host (hosts append;
        never redefine).
      '';
    };

    backends = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "weaviate"
          "milvus"
          "elasticsearch"
        ]
      );
      default = [ ];
      description = ''
        Docker-wrapper store ids to stand up (KA-09.2, ko#111 — §5.4 Shape
        3): each id rides a virtualisation.oci-containers backend container
        on the podman substrate the container module manages — NOT a nix
        package, and never a bare global docker enable. The per-id posture
        note lives in docs/guide/o-03-docker-wrapper-stores.md.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Native rows (KA-09.1). jina-embeddings-cli resolves only when the
    # packages overlay is composed (manifest pkgs/jina-embeddings-cli/
    # default.nix); the ?? guard keeps host evaluation green at revisions
    # without it.
    kailash.layers.ops.categories.o-03.packages =
      [
        pkgs.chromadb
        pkgs.chromadb-cli
        pkgs.qdrant
        pkgs.faiss
        pkgs.python3Packages.txtai
      ]
      ++ lib.optionals (pkgs ? jina-embeddings-cli) [ pkgs.jina-embeddings-cli ];

    environment.systemPackages = cfg.packages;

    # chromadb: the AI-native embedding database (module probed at the
    # pin: services.chromadb.enable, package default
    # pkgs.python3Packages.chromadb).
    services.chromadb.enable = true;

    # qdrant: the Rust vector-search server (module probed at the pin:
    # services.qdrant.enable + pkgs.qdrant). Loopback binding by default —
    # the A-7 rip surface (vector-db-ripper, manifest a-07) trains against
    # local stores; a remote-facing move is an explicit operator decision.
    services.qdrant.enable = true;
    services.qdrant.settings.service.host = lib.mkDefault "127.0.0.1";

    # pgvector: vector similarity search for PostgreSQL (ko#110: "pgvector
    # module"). The NixOS shape is the extension inside the server package
    # set: postgresql_16.withPackages composes pgvector into the server
    # (probed at the pin: postgresql_15/16/17.withPackages all evaluate
    # with postgresqlPackages.pgvector). Extension creation stays an
    # operator SQL step (CREATE EXTENSION vector;) inside a database — the
    # module does not auto-create extensions, and there is NO standalone
    # pgvector derivation.
    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql_16.withPackages (
      p: [ p.pgvector ]
    );

    # Docker-wrapper stores (KA-09.2, ko#111): one oci-containers backend
    # container per declared id, on the podman rootless substrate the
    # container module manages. autoStart = false: the store container is
    # DECLARED by the category and STARTED by the operator (the
    # no-auto-start posture, §11.2 — heavy stores never listen unbidden).
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers = lib.listToAttrs (
      map
        (id: {
          name = "kailash-o-03-${id}";
          value = {
            image = backendImages.${id};
            autoStart = false;
            environment.KAILASH_O3_POSTURE = "docker-wrapper-module";
          };
        })
        cfg.backends
    );
  };
}
