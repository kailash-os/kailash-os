# The Layer OPS fold (§4.2). Category modules land per their wave items;
# this fold imports them all — every category option defaults OFF, so the
# CORE substrate (profiles/minimal.nix) installs nothing from OPS until a
# profile or host opts in (the §4.5 opt-in-by-default contract).
#
# KA-09.1 (ko#110): the O-3 vector stores & retrieval module (typed
# backends mixin + the chromadb/qdrant/pgvector service wiring).
#
# KA-08.1/08.2 (ko#105/#106): the O-1 + O-2 category modules (the DS
# stack native rows + the bespoke overlay rows) + the mlflow SERVICE
# module (the pairing-thesis target — enable defaults false, loopback
# bind default, the lab-default unauth binding documented never
# defaulted — spec §8 Phase 3).
#
# KA-09.4 (ko#113): the O-6 Docs & Authoring category module (the
# publishing/authoring stack; texlive-full stays the opt-in data row,
# dradis/pwndoc-ng the module rows — both never in the install set).
#
# KA-25 (os#25): the O-7 Agent & MCP Operability category module — the
# exp faces route through the §11.2 lab-mode gate (kailash.safety.-
# extraTools; the FIRST category module wiring exp rows at the
# category level), mcp-inspector rides the §4.5 package-list surface,
# and the capability-grants posture (modules/base/agent-grants.nix)
# scopes agent actions on top (a grant never bypasses the gate).
{ lib, ... }: {
  imports = [
    ./o-01-mlops-ml-engineering.nix
    ./o-03-vector-stores-retrieval.nix
    ./o-04-local-llm-inference-labs.nix
    ./mlflow-service.nix
    ./o-02-compute-serving-infrastructure.nix
    ./o-06-documentation-reporting-authoring.nix
    ./o-05-ai-engineering-sdks-dev-env.nix
    ./o-07-agent-mcp-operability.nix
  ];
}
