# Layer CLASSIC — C-10 Runtime AppSec for AI Systems (KA-07.4, ko#102;
# plan §4.5).
#
# WATCHED RED STUB — this commit deliberately installs NOTHING: the
# manifest-generated id list is not yet consumed, so an enabled c-10 host
# resolves an EMPTY install set and the flake's c-10-options leg (the
# non-empty assertion) fails — the watched red this lane drives GREEN in
# the next commit, same shape as the ko#96 exemplar's red.
#
# The §4.5 category-module shape it completes (config-only mount; the
# KA-09.1 spine owns the enable/packages baseline members on
# kailash.layers.classic.categories.c-10):
#   * installable ids flow from generated/manifest-ids.json
#     (categories.c-10-runtime-appsec-ai.installable), produced by
#     tools/gen-categories.py + `make gen-categories`, never hand-maintained;
#   * the reviewed binding table maps id → pkgs attr at the pinned
#     packages rev (probed per entry, never assumed id==attr);
#   * `mkIf enable` installs — opt-in by default, the §4.5 posture;
#   * the zaproxy row stays OUT: its PRIMARY home is c-03 (the c-10
#     secondary-home note is recorded in the GREEN binding table header —
#     the generator keys packages by primary category only).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-10;
in
{
  config = {
    # RED: consumes nothing yet — the install set stays empty and the
    # c-10-options leg fails until the GREEN commit lands.
    kailash.layers.classic.categories.c-10.packages = lib.mkForce [ ];

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
