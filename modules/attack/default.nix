# Layer ATTACK category modules (§4.2 fold + §4.5 contract). New category
# modules join this import list (KA-13.1: a-01/a-02; KA-13.2 side-car: the
# a-02 data-pack option module).
{ lib, ... }: {
  imports = [
    ./a-01-ai-recon.nix
    ./a-02-llm-prompt-injection.nix
    ./a-02-data-packs.nix
  ];
}
