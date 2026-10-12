# Layer ATTACK category modules (§4.2 fold + §4.5 contract). Each file
# is one §4.5 category module: `options.kailash.layers.attack.categories.<id>`
# composed config-only (the spine owns the enable/packages baseline
# members — modules/base/layer-tree.nix). The first two off the classic
# exemplar (KA-13.1, ko#103). New category modules join this import list.
{ lib, ... }: {
  imports = [
    ./a-01-ai-recon.nix
    ./a-02-llm-prompt-injection.nix
  ];
}
