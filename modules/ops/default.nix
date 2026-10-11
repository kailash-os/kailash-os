# Layer OPS category modules (§4.2 fold). Each file is one §4.5 category
# module: typed options under kailash.layers.ops.categories.<id> + the
# mkIf-enable install config. New category modules join this import list.
{ lib, ... }: {
  imports = [
    ./o-03-vector-stores-retrieval.nix
  ];
}
