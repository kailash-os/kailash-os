# The Layer OPS fold (§4.2). Category modules land per their wave items;
# this fold imports them all — every category option defaults OFF, so the
# CORE substrate (profiles/minimal.nix) installs nothing from OPS until a
# profile or host opts in (the §4.5 opt-in-by-default contract).
#
# KA-09.1 (ko#110): the O-3 vector stores & retrieval module (typed
# backends mixin + the chromadb/qdrant/pgvector service wiring).
#
# KA-08.1 (ko#105): the O-1 category module (the DS stack native rows +
# the bespoke overlay rows) + the mlflow SERVICE module (the
# pairing-thesis target — enable defaults false, loopback bind default,
# the lab-default unauth binding documented never defaulted — plan §9
# Phase 3).
{ lib, ... }: {
  imports = [
    ./o-01-mlops-ml-engineering.nix
    ./o-03-vector-stores-retrieval.nix
    ./mlflow-service.nix
  ];
}
