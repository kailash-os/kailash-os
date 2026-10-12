# Layer CLASSIC — C-3 Web Application Assessment (KA-07.1, ko#99; plan §4.5).
#
# RED STUB: the §4.5 category module's install wiring lands in the GREEN
# commit — the manifest-generated id list
# (generated/manifest-ids.json, categories.c-03-web-application-assessment
# .installable) resolves through a reviewed binding table (probed at
# nixpkgs 8c3ced + packages pin 7374e7a, never assumed id==attr) into
# kailash.layers.classic.categories.c-03.packages then. Until then an
# enabled c-03 host installs NOTHING — the c-03-options check's non-empty
# assertion is the watched red. The typed c-03 surface already exists
# (modules/base/layer-tree.nix, the KA-09.1 spine) — profiles can already
# compose the switch; nothing installs behind it until GREEN.
{ ... }:

{ }
