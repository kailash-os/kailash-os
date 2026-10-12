# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category o-03-vector-stores-retrieval
# from the pinned packages manifest; the committed lists are
# drift-checked every PR by the OS flake's category checks.
#
# Excluded at this pin (status → owner — never list entries):
#   module   → the row's own service module: elasticsearch, milvus, pgvector, weaviate
#
# PURE DATA on purpose: `native` carries pkgs attr PATHS —
# the category module's resolver ?-guards every path (green
# eval at revisions without the overlay or where a native attr
# moves); `bespoke` carries the packages-overlay rows.
{ ... }:

{
  o-03-vector-stores-retrieval = {
    native = [
      [ "python3Packages" "chromadb" ]
      [ "faiss" ]
      [ "qdrant" ]
      [ "python3Packages" "txtai" ]
    ];
    bespoke = [
      { id = "jina-embeddings-cli"; derivation = "pkgs/jina-embeddings-cli/default.nix"; }
    ];
  };
}
