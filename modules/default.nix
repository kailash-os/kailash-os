# Folds the category tree into one importable module list (§4.2).
# Layer modules land per their roadmap items; empty dirs are folded as
# no-ops until then.
{ lib, ... }: {
  imports = [
    ./base
    ./classic
    ./attack
    ./defence
    ./build
  ];
}
