# Layer OPS — O-6 Documentation, Reporting & Authoring (KA-09.4, ko#113;
# spec §2.5, §9 Phase 3). The §4.5 category module, config-only on the
# §3.6 typed spine (modules/base/layer-tree.nix — the per-id option-decl
# tree; the same mount every Wave-5/6 category module copies). The spine
# owns enable + packages at kailash.layers.ops.categories.o-06 (the SHORT
# manifest id — the tree keys categories by the §3.6 census ids; the
# module FILE keeps the manifest's long id); this module declares NOTHING
# (no extra member) and consumes the spine members:
#
#   enable   — the category switch (spine default false; profiles opt in):
#              the O-6 authoring stack — the publishing/authoring tooling
#              the deliverables (reports, docs, the paper) render through
#              (quarto, pandoc, typst, mdbook, drawio, excalidraw,
#              mermaid-cli, obsidian). Nothing installs until enabled
#              (§4.5 opt-in by default).
#   packages — the generated, manifest-driven install set (config-assigned
#              below; hosts compose/append on the spine option — never
#              redefine).
#
# ROUTING CONTRACT (the manifest rows are the routing record):
#   * texlive-full (packaging.status "data") is NEVER in this list — a
#     data-pack row: the TeX Live scheme-full bundle is the opt-in LaTeX
#     data pack (the kailash-data packs own it; data rows never ride a
#     category install set). quarto typesets PDFs through its own bundled
#     engine; a TeX install stays an explicit operator opt-in.
#   * dradis + pwndoc-ng (packaging.status "module") are NEVER in this
#     list — module-status rows ship as their own systemd service modules
#     (the service-module ledger); pwndoc-ng's manifest PRIMARY is
#     c-09-forensics-ir-reporting with o-06 as a secondary tag, so nothing
#     duplicates here (§4.5 cross-references resolve via secondary tags).
#   * safety.level == "exp" rows would NEVER land here (§11.2 double-key
#     gate; every o-06 row is safe at this pin).
#
# DATA CONTRACT: same as the O-1 module (the committed emit under
# modules/ops/generated/ is pure generator output, drift-checked EVERY PR
# by checks.o-06-generated-drift: the generator run against the PINNED
# packages manifest through the flake input == committed || red).
#
# BINDING TABLE (probed at nixpkgs 8c3cede7ddc26bd659d2d383b5610efbd2c7a16e
# + packages pin 7374e7a7650513bdaed11863a2fcb076041a890c — never assumed
# id == attr):
#   * pandoc        → pkgs.pandoc, whose driver derivation is
#                     pandoc-cli-3.7.0.2 at this pin (nixpkgs split
#                     pandoc → pandoc-cli; `pkgs.pandoc` is the kept
#                     alias, so the manifest id binds bare — pname
#                     pandoc-cli is the drop-free binding note);
#   * drawio        → pkgs.drawio (31.4.5) — the DESKTOP editor
#                     derivation; no `drawio-desktop` attr at this pin
#                     (probed null) and the manifest id draws itself;
#   * excalidraw    → manifest-bespoke row (pkgs/excalidraw/default.nix):
#                     resolves through the packages overlay when the OS
#                     flake composes overlays.default; no nixpkgs
#                     excalidraw attr at this pin (probed null) — the
#                     overlay-guard drops the row WITHOUT breaking eval
#                     at revisions without the overlay (the same
#                     return-rule as c-01's sublist3r/spiderfoot); the
#                     web-app build is an overlay lane landing, not a
#                     binding drop;
#   * mermaid-cli   → pkgs.mermaid-cli (11.17.0; binds bare — an
#                     electron-wrapped headless renderer; no top-level
#                     `mmdc` attr at this pin, probed null; the binary
#                     inside the package is mmdc);
#   * obsidian      → pkgs.obsidian (1.13.7) — nixpkgs-unfree-class
#                     licence (the manifest row is LicenseRef-Proprietary
#                     with packaging.status "native"): allowed HERE by
#                     the flake's EXPLICIT allowUnfree = true posture
#                     (flake.nix pkgs.config) — a named flake decision,
#                     never a silent default;
#   * quarto, typst, mdbook — bind bare (pnames quarto 1.10.18, typst
#                     0.15.1, mdbook 0.5.4; quarto 1.10.18 renders .qmd
#                     — the VM quarto-render acceptance rides the VM wave
#                     with the ko#109/ko#98 smokes).
# All eight installable manifest rows bound at this pin: ZERO attr-name
# drops (texlive-full and dradis are the routing exclusions, not drops).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.ops.categories.o-06;

  # The generator's committed emit = pure structure (no package attrs).
  generated =
    (import ./generated/o-06-documentation-reporting-authoring.nix {
      inherit lib;
    }).o-06-documentation-reporting-authoring;

  # Resolver, §4.5: every attr path ?-guarded (green eval at revisions
  # where the overlay is absent or a native attr moves).
  resolveNative = path:
    if lib.attrByPath path null pkgs != null then [ (lib.getAttrFromPath path pkgs) ] else [ ];
  resolveBespoke = row:
    if lib.attrByPath [ row.id ] null pkgs != null
    then [ (lib.getAttrFromPath [ row.id ] pkgs) ]
    else [ ];

  # The manifest-driven install set = the generated rows resolved.
  # Hosts compose/append on the spine option; never redefine — and never
  # a config-assignment of cfg.packages back into the tree (a mkIf
  # self-assignment re-enters the layers merge mid-collection,
  # eval-probed by the O-1 lane).
  installSet = lib.flatten
    (map resolveNative generated.native ++ map resolveBespoke generated.bespoke);
in
{
  config = {
    # The manifest-driven install set (7 native rows + the excalidraw
    # bespoke row when the packages overlay is composed — all 8
    # installable manifest rows bound at this pin; texlive-full is the
    # data row and dradis the module row, both excluded by construction).
    kailash.layers.ops.categories.o-06.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default.
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
