# Layer CLASSIC — C-10 Runtime AppSec for AI Systems (KA-07.4, ko#102;
# spec §3.5).
#
# The fifth §4.5 category module off the KA-06.1 exemplar (same shape —
# spine-owned typed surface, config-only install mount, mkIf enable).
# os#210 purge re-basis (2026-10-14): the pre-purge scanner/toolkit
# rows were phantom-upstream (claimed kailash-os or invented org
# upstreams that never existed) — removed; names live in the registry
# (kailash-os#210). The category's
# real surface is mitmproxy (native) + zaproxy riding as secondary.
#
# Binding table:
#   * mitmproxy → pkgs.mitmproxy (bare; native row);
#   * zaproxy (OWASP ZAP; pkgs.zap at this nixpkgs, v2.17.0) stays OUT:
#     its PRIMARY home is C-3 Web Application Assessment and the
#     generator keys package lists by primary category — c-10's
#     secondary-home row is recorded HERE (binding-table note), never
#     mounted twice.
#
# GREEN: the manifest-driven install set (mitmproxy at this pin) with
# the SAME c-10-options assertions (FALSE-default floor, non-empty
# enabled composition, mitmproxy present) passing through the SAME eval.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-10;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-10-runtime-appsec-ai.installable;

  # The binding table: mitmproxy binds bare at this pin (the only real
  # c-10 row post-purge).
  attrFor = id:
    {
      "mitmproxy" = pkgs.mitmproxy or null;
    }."${id}" or (pkgs."${id}" or null);

  # Bind → drop the null (overlay-pending at this pin) and the
  # broken-marked rows; dedupe (one primary slot, one install).
  installSet = lib.unique
    (lib.filter
      (p: p != null && !(p.meta.broken or false))
      (map attrFor ids));
in
{
  config = {
    # The manifest-driven install set (mitmproxy native — the only
    # real c-10 row post-os#210; the phantom scanner/toolkit rows were
    # removed per kailash-os#210).
    kailash.layers.classic.categories.c-10.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
