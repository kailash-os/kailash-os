# The full profile (KA-06.2, ko#97): the CORE floor + every SHIPPED
# category enabled — the four Wave-5 CLASSIC modules this lane landed
# (c-01, c-04, c-02, c-06). The remaining CLASSIC categories (C-3, C-5,
# C-8, C-9, C-10 — KA-07.x) and the other layers' categories join this
# list as their modules land; the profile is the composition the
# kailash-full-style deliverables build on.
#
# The enabled categories carry the manifest's safe|requires-target rows
# (exp-class tools never reach a package list — the lab-mode gate owns
# that surface).
{ lib, ... }:

{
  imports = [ ./minimal.nix ];

  networking.hostName = lib.mkDefault "kailash-full";

  # The shipped §4.5 category set (opt-in by default; the profile opts in).
  kailash.layers.classic.categories.c-01.enable = lib.mkDefault true;
  kailash.layers.classic.categories.c-02.enable = lib.mkDefault true;
  kailash.layers.classic.categories.c-04.enable = lib.mkDefault true;
  kailash.layers.classic.categories.c-06.enable = lib.mkDefault true;
}
