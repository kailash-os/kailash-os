# Layer CLASSIC — C-3 Web Application Assessment (KA-07.1, ko#99; plan §4.5).
#
# The tenth §4.5 category module — the exemplar's shape (c-01, KA-06.1;
# c-06's namedDrops extension) on the tenth manifest category: the typed
# spine (modules/base/layer-tree.nix) owns enable + packages at
# kailash.layers.classic.categories.c-03 (the SHORT manifest id — the
# tree keys categories by the §3.6 census ids; the module FILE keeps the
# manifest's long id); this module is a CONFIG-ONLY mount of the
# manifest-driven install set; mkIf enable installs (opt-in by default).
#
# GREEN (this commit): the module consumes the generated artifact —
# the RED stub (installs NOTHING) is replaced by the 7-entry install
# set; the SAME check assertions (non-empty set, flagship PATH) pass
# through the SAME eval (the c-03-options leg).
#
# VERSION PINNING (ko#99's "pinned to exact versions / identical builds
# everywhere" acceptance, read against the manifest): the c-03 rows
# carry NO version fields in the pinned manifest (manifest/tools.yaml
# version is null on all 10 rows at packages pin 7374e7a), and a
# per-tool version option (categories.c-03.<tool>.pin) would be hollow
# config — nothing in the manifest or an in-repo lock can pin a flake
# input attr, so the choice would silently default to the nixpkgs rev.
# The honest landing: the flake.lock pins nixpkgs (8c3ced) +
# kailash-packages (7374e7a) → every c-03 tool resolves to the same
# derivation on every machine that evaluates the flake — identical
# builds everywhere rides the LOCK, not per-tool version strings.
# Versions at this pin (probed): zap 2.17.0, burpsuite 2026.8,
# caido(-desktop) 0.57.0.
#
# BINDING TABLE (probed at nixpkgs 8c3ced + packages pin 7374e7a — never
# assumed id==attr):
#   * zaproxy → pkgs.zap — nixpkgs' OWASP ZAP flagship attr is `zap`
#     (pname zap, 2.17.0); probed ABSENT at this pin: pkgs.zaproxy,
#     pkgs.zaprox, pkgs.zaprox-community, pkgs.owasp-zap;
#   * caido → pkgs.caido — at this pin nixpkgs SPLIT caido into
#     caido-cli + caido-desktop; the bare `pkgs.caido` attr remains as
#     an alias (eval warning; resolves the desktop derivation,
#     unfree 0.57.0). Kept on the alias per the literal manifest id;
#     the drop-guard makes the row safe if the alias ever disappears.
#   Everything else binds bare; no c-03 row is broken-marked at this
#   pin (all seven bound rows probed meta.broken = false).
#
# Named drops WITH reasons (the c-06 angr rule — build/eval-evidenced,
# the row returns when the packaging gap closes):
#   * clairvoyance — eval-REFUSED at this pin: the row's python
#     dependency python3.14-aiounittest-1.5.0 refuses instantiation
#     ("unsupportedPython (kind broken): aiounittest-1.5.0 not
#     supported for interpreter python3.14"), so binding it would break
#     the whole category's eval — dropped until the dep's python
#     support lands.
#   * gopherus, sstimap — overlay-pending: manifest packaging
#     .derivation rows (pkgs/gopherus, pkgs/sstimap) with NO attr in
#     the packages overlay at this pin → they fall to the bare guard,
#     resolve null and drop WITHOUT breaking eval.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.classic.categories.c-03;

  ids = (builtins.fromJSON (builtins.readFile ../../generated/manifest-ids.json))
    .categories.c-03-web-application-assessment.installable;

  attrFor = id:
    {
      "zaproxy" = pkgs.zap or null;
      "caido" = pkgs.caido or null;
    }.${id} or (pkgs."${id}" or null);

  # Bind → drop the named drops (eval-evidenced above), then the nulls
  # (missing-at-pin: gopherus, sstimap at this overlay).
  boundIds = lib.filter (id: id != "clairvoyance") ids;
  installSet = lib.filter (p: p != null) (map attrFor boundIds);
in
{
  config = {
    # The manifest-driven install set (7 of the 10 manifest rows at this
    # pin: clairvoyance eval-refused (named drop), gopherus + sstimap
    # overlay-pending drops via the guard).
    kailash.layers.classic.categories.c-03.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default.
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
