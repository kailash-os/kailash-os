# Layer CLASSIC — C-7 Signal & SDR Processing (KA-07.2, ko#100; §4.5).
#
# DECISION (KA-07.2, recorded here per the manifest note) — C-7 ships as
# the kailash-data.sdr-tools OPT-IN DATA PACK, not as a category module
# install surface:
#
#   1. The manifest types c-07 as kind:data-pack, opt_in:true
#      (manifest/categories.yaml: "the sole radio-adjacent concession
#      (§4.1); category of record but opt-in data-pack — never on
#      default profiles/ISOs (D7)"). Of its six rows, five are
#      status:data (gnuradio, gqrx, hackrf-tools, sox, librosa) and the
#      generator EXCLUDES every data row from category install sets —
#      generated/manifest-ids.json carries c-07 with installable =
#      [pysox] (the lone bespoke row) and the five rows in excluded.
#   2. The data-pack derivations (gnuradio/gqrx/hackrf host tools/sox/
#      librosa/pysox assembled as data derivations) live in
#      kailash-packages, NOT in this OS repo — this file deliberately
#      declares NO options and mounts NO config. There is no
#      kailash-data option namespace on the OS side yet; the pack's
#      opt-in mounting lands on the packages repo's lane when the pack
#      grows (pysox's bespoke derivation included — at this pin it is
#      overlay-pending and would drop through the bare guard anyway).
#   3. OFF EVERYWHERE BY DEFAULT: the typed spine entry
#      (kailash.layers.classic.categories.c-07, enable default false)
#      exists in modules/base/layer-tree.nix, and this file never flips
#      it — no profile sets c-07.enable, so minimal/standard/full stay
#      C-7-free. The flake's c-07-optin-posture leg pins that posture
#      (default false asserted on the CORE substrate).
#   4. REVISIT CONDITION (the manifest's "decision + revisit condition
#      recorded in the module comment"): when the kailash-data.sdr-tools
#      data pack lands in kailash-packages, revisit this file to decide
#      the OS-side mounting shape (a kailash-data option namespace plus
#      an opt-in host key, or a services-style module wrapping the pack
#      derivation) — until then the category of record stays a
#      packages-repo derivation surfaced through docs, and any demand
#      for the pack goes through its own opt-in lane, never a profile
#      flip here.
#
# The §4.5 contract note: a category module that declares nothing is a
# valid §4.5 citizen — the spine owns the typed enable/packages entry;
# this stub exists so the category of record has a module FILE (per the
# manifest census, layer-tree's typed id list) and so the opt-in
# posture is legible in-review, not implicit.
{ config, lib, pkgs, ... }:

{
  # INTENTIONALLY EMPTY — see the DECISION block above. No options, no
  # config mounts; the spine's typed c-07 entry (enable default false)
  # stays the whole surface in this repo.
}
