# Layer CLASSIC — C-10 Runtime AppSec for AI Systems (KA-07.4, ko#102;
# spec §3.5).
#
# The fifth §4.5 category module off the KA-06.1 exemplar (same shape —
# spine-owned typed surface, config-only install mount, mkIf enable).
# ais IS the category primary per §3.2 (ai-scanner, the AISVS-scoped
# runtime surface); mitmproxy is the install-set flagship at this pin
# (the primary's derivation has not landed in the packages overlay yet).
#
# Binding table (probed at nixpkgs 8c3cede + packages pin 7374e7a — never
# assumed id==attr):
#   * mitmproxy → pkgs.mitmproxy (bare; native row — the install-set
#     flagship at this pin);
#   * oauth-mcp-prober, sdl3-stream-fuzzer, llm-fuzzer, ais →
#     manifest-bespoke rows through the packages overlay; their
#     derivations have NOT landed at this pin (pkgs/ carries art,
#     auto-call, counterfit, dnsrecon, garak, kailash, promptfoo, pyrit,
#     subfinder) → they drop through the bare guard and return when
#     their packaging lanes land (the exemplar's overlay-pending rule);
#   * ais IS the c-10 primary per the manifest — the bare-guard miss is
#     an overlay-pending drop (returns when the derivation lands), not a
#     data-row exclusion;
#   * zaproxy (OWASP ZAP; pkgs.zap at this nixpkgs, v2.17.0) stays OUT:
#     its PRIMARY home is C-3 Web Application Assessment and the
#     generator keys package lists by primary category — c-10's
#     secondary-home row is recorded HERE (binding-table note), never
#     mounted twice.
#
# GREEN (this commit): the watched-RED stub (installs NOTHING) becomes
# the manifest-driven install set (mitmproxy at this pin; the four
# bespokes return via the guard); the SAME c-10-options assertions
# (FALSE-default floor, non-empty enabled composition, mitmproxy
# present) pass through the SAME eval.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-10;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-10-runtime-appsec-ai.installable;

  # The binding table: mitmproxy binds bare at this pin; the four
  # bespoke rows fall to the bare guard (pkgs."<id>" or null), resolve
  # null and drop WITHOUT breaking eval — the overlay row returns them.
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
    # The manifest-driven install set (1 of the 5 installable ids at
    # this pin: mitmproxy native; oauth-mcp-prober, sdl3-stream-fuzzer,
    # llm-fuzzer, ais overlay-pending; the vulnerable-llm-apps and
    # asvs-verification-toolkit data rows are excluded by the generator —
    # data-packs never ride a package list).
    kailash.layers.classic.categories.c-10.packages = installSet;

    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
