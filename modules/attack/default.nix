# Layer ATTACK category modules (§4.2 fold + §4.5 contract). New category
# modules join this import list (KA-13.1: a-01/a-02; KA-13.2 side-car: the
# a-02 data-pack option module).
{ lib, ... }: {
  imports = [
    ./a-01-ai-recon.nix
    ./a-02-llm-prompt-injection.nix
    ./a-02-data-packs.nix
    # KA-22 (kailash-os#22): the A-3/A-4 long-tail category modules join the fold
    ./a-03-agentic-mcp-tool-use.nix
    ./a-04-model-supply-chain.nix
    # KA-23 (kailash-os#23): the A-5/A-6/A-7/A-8 long-tail category
    # modules join the fold (the a-07 exp-only ledger + §6.5 pairing
    # legs ride the integration-mlflow-attack leg set)
    ./a-05-model-extraction-inversion.nix
    ./a-06-multimodal-physical-ai.nix
    ./a-07-ai-system-exploitation.nix
    ./a-08-data-poisoning.nix
  ];
}
