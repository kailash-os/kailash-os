# Layer OPS — O-5 AI Engineering SDKs & Dev Environment (KA-08.3, os#107;
# spec §2.5, §9 Phase 3). The §4.5 category module, config-only on the
# §3.6 typed spine (modules/base/layer-tree.nix — the per-id option-decl
# tree; the same mount every Wave-5/6 category module copies). The spine
# owns enable + packages at kailash.layers.ops.categories.o-05 (the SHORT
# manifest id — the tree keys categories by the §3.6 census ids; the
# module FILE keeps the manifest's long id); this module declares NOTHING
# (no extra member) and consumes the spine members:
#
#   enable   — the category switch (spine default false; profiles opt in):
#              the O-5 builder layer — the LLM/agent SDKs (langchain,
#              langgraph, llama-index, openai, anthropic, google-genai,
#              crewai), the ML frameworks (pytorch cpu default +
#              torch-nvidia explicit variant NEVER here, tensorflow, jax,
#              onnxruntime, transformers, datasets, peft, trl) and the dev
#              environment (vscode, neovim, uv, ruff, mypy, the python313
#              interpreter, python-lsp-server, quarto). Nothing installs
#              until enabled (§4.5 opt-in by default).
#   packages — the generated, manifest-driven install set (config-assigned
#              below; hosts compose/append on the spine option — never
#              redefine).
#
# ROUTING CONTRACT (the manifest rows are the routing record):
#   * autogen (packaging.status "bespoke") resolves through the packages
#     overlay when the OS flake composes overlays.default — ?-guarded by
#     id, so host evaluation stays green at revisions without the overlay
#     (the same return-rule as o-03's jina-embeddings-cli).
#   * pytorch's Shape-4 CUDA variant (pkgs/torch-nvidia, kailash-os#108)
#     is NEVER in the install set — the explicit -nvidia variant is
#     pulled only by labelled jobs; the row installed here is the
#     non-GPU default torch (cudaSupport = false, the §5.3 Shape 4
#     posture — never a global cudaSupport flip anywhere).
#   * quarto (a manifest o-05 secondary) is a primary o-06 row and never
#     duplicated from its secondary tag (§4.5: secondaries are
#     cross-reference tags only).
#   * safety.level == "exp" rows would NEVER land here (§11.2 double-key
#     gate; every o-05 row is safe at this pin).
#
# DATA CONTRACT: same as the O-1/O-6 modules (the committed emit under
# modules/ops/generated/ is pure generator output, drift-checked EVERY PR
# by checks.o-05-generated-drift: the generator run against the PINNED
# packages manifest through the flake input == committed || red).
#
# BINDING TABLE (probed at nixpkgs 8c3cede7ddc26bd659d2d383b5610efbd2c7a16e
# with the sentinel tryEval probe — never assumed id == attr):
#   * python3Packages.* — the o-05 Python SDK surface names (langchain,
#     langgraph, llama-index, openai, anthropic, google-genai, crewai,
#     torch, torchvision, torchaudio, tensorflow, jax, onnxruntime,
#     transformers, datasets, peft, trl, huggingface-hub,
#     python-lsp-server) ALL bind inside the pinned python3Packages at
#     this pin (probed versions live in the generated file's header); the
#     generator's NATIVE_ATTRS table carries the python3.13-era
#     python3Packages paths (the flake pin predates python3Packages;
#     nixpkgs' python3Packages.wandb divergence precedent, o-01);
#   * uv         → pkgs.uv (0.11.17; the uvTools.uv sub-attr is not a
#     derivation at this pin — probed null);
#   * ruff       → pkgs.ruff (0.15.15; alias-exact, also inside
#     python3Packages at the same version);
#   * mypy       → pkgs.mypy (1.20.1; same duality — top-level and
#     python3Packages agree);
#   * neovim     → pkgs.neovim (0.12.2);
#   * vscode     → pkgs.vscode (1.122.1 — the OPENVSX build; the os#107
#     issue text's `vscode` names the editor derivation — the
#     code-server and vscode-with-extensions shapes stay out of the
#     default set);
#   * code-server, transformers, datasets, peft, trl — all bound by the
#     generated rows (native table + python3Packages table above);
#   * python313  → pkgs.python313 (3.13.13) — the explicit interpreter;
#     note this pin's python3 == 3.13.13 already, so python313 binds to
#     the same interpreter series it names (probed, not assumed);
#   * crewai (1.14.4), openai-python → python3Packages.openai (2.33.0),
#     anthropic-python → python3Packages.anthropic (0.97.0),
#     google-genai → python3Packages."google-genai" (1.67.0),
#     llama-index → python3Packages."llama-index" (0.14.19 — the
#     meta-package; llama-index-core is the same surface), langchain →
#     python3Packages.langchain (1.2.15), langgraph →
#     python3Packages.langgraph (1.1.10).
# All 25 installable manifest rows bound at this pin: ZERO attr-name
# drops (autogen rides the overlay guard, not a drop).
#
# IMPORT SMOKE (checks.o-05-sdk-imports): the devShell's resolved surface
# is exercised by actually importing the SDK stack inside the shell env —
# the real `python -c` import chain, NOT a pnames-only claim; the
# acceptance ("imports resolve in a devShell") is checked, not claimed.
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.ops.categories.o-05;

  # The generator's committed emit = pure structure (no package attrs).
  generated =
    (import ./generated/o-05-ai-engineering-sdks-dev-env.nix {
      inherit lib;
    }).o-05-ai-engineering-sdks-dev-env;

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
    # The manifest-driven install set (24 native rows resolved on the
    # pinned nixpkgs + the autogen bespoke row when the packages overlay
    # is composed; the generator + drift check own the regeneration).
    kailash.layers.ops.categories.o-05.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default.
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;
  };
}
