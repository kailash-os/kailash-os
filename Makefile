# make — kailash-os (KA-06.1, ko#96): `make gen-categories`.
#
# The packages repo is a sibling checkout (../kailash-packages — this
# repo's own flake.lock names it as a flake input, so the two repos
# naturally sit side by side). `make gen-categories` regenerates
# generated/manifest-ids.json from the sibling checkout's manifest (the
# reviewed pre-push convention; the flake parity leg re-runs the SAME
# generator against the PINNED manifest and drifts red on mismatch, so
# a hand-edit can never silently diverge).
PACKAGES_DIR ?= ../kailash-packages

.PHONY: gen-categories check

gen-categories:
	python3 tools/gen-categories.py \
	  --manifest-file "$(PACKAGES_DIR)/manifest/tools.yaml" \
	  --out generated/manifest-ids.json

check:
	nix flake check
