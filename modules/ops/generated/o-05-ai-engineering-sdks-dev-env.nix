# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with
#   python3 tools/gen-category-packages.py --category o-05-ai-engineering-sdks-dev-env
# from the pinned packages manifest; the committed lists are
# drift-checked every PR by the OS flake's category checks.
#
# Excluded at this pin (status → owner — never list entries):
#   (none)
#
# PURE DATA on purpose: `native` carries pkgs attr PATHS —
# the category module's resolver ?-guards every path (green
# eval at revisions without the overlay or where a native attr
# moves); `bespoke` carries the packages-overlay rows.
{ ... }:

{
  o-05-ai-engineering-sdks-dev-env = {
    native = [
      [ "python3Packages" "anthropic" ]
      [ "code-server" ]
      [ "python3Packages" "crewai" ]
      [ "python3Packages" "datasets" ]
      [ "python3Packages" "google-genai" ]
      [ "python3Packages" "jax" ]
      [ "python3Packages" "langchain" ]
      [ "python3Packages" "langgraph" ]
      [ "python3Packages" "llama-index" ]
      [ "mypy" ]
      [ "neovim" ]
      [ "python3Packages" "onnxruntime" ]
      [ "python3Packages" "openai" ]
      [ "python3Packages" "peft" ]
      [ "python3Packages" "python-lsp-server" ]
      [ "python313" ]
      [ "python3Packages" "torch" ]
      [ "ruff" ]
      [ "python3Packages" "tensorflow" ]
      [ "python3Packages" "torchaudio" ]
      [ "python3Packages" "torchvision" ]
      [ "python3Packages" "transformers" ]
      [ "python3Packages" "trl" ]
      [ "uv" ]
      [ "vscode" ]
    ];
    bespoke = [
      { id = "autogen"; derivation = "pkgs/autogen/default.nix"; }
    ];
  };
}
