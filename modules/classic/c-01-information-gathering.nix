# Layer CLASSIC — C-1 Information Gathering (KA-06.1, ko#96; plan §4.5).
#
# RED STUB: the §4.5 exemplar's install wiring lands in the GREEN
# commit — the manifest-generated package list
# (generated/manifest-ids.json via tools/gen-categories.py +
# `make gen-categories`) is not consumed yet, so an enabled c-01 host
# installs nothing (the c-01-exemplar check's non-empty assertion is
# the watched red). The typed c-01 enable already exists
# (modules/base/layer-tree.nix, the KA-09.1 spine) — profiles can
# already compose the switch; nothing installs behind it until GREEN.
{ ... }:
{ }
