# Layer OPS — O-4 Local LLM & Inference Labs (KA-09.3, ko#112; spec §3.5).
#
# The §4.5 category module, config-only on the §3.6 typed spine
# (modules/base/layer-tree.nix — the same mount as the O-1/O-2/O-3
# category modules; the tree keys categories by the SHORT id o-04, the
# form profiles and the flake checks address; this module FILE keeps
# the manifest's long id). Consumes the spine members:
#
#   enable   — the category switch (spine default false; profiles opt
#              in, §4.5 opt-in by default). O-4 Local LLM & Inference
#              Labs: ollama (the PRIMARY home) + llama.cpp inference
#              engines + open-webui chat UI. Nothing installs and
#              nothing listens until the category switch is ON — every
#              service below rides mkIf cfg.enable (+ its own sibling
#              toggle), never an unconditional enable.
#   packages — the generated, manifest-driven install set (config-
#              assigned below; hosts compose/append on the spine
#              option — never redefine).
#
#   EXTRA sibling member (declared HERE on the same tree path, the
#   o-02 bare-tree sibling pattern — merges without structural change):
#     webui   — the open-webui chat-UI toggle: rides the UPSTREAM
#               services.open-webui module (probed at the pin), wired
#               to the loopback ollama endpoint this module stands up
#               (the ko#112 acceptance: "open-webui reachable against
#               ollama"). Default ON WITH the category — the pairing is
#               the point (a chat front-end over the local ollama); the
#               sub-toggle turns the UI off for an engines-only host.
#               The category switch remains THE opt-in: category OFF ⇒
#               nothing rises, toggle or not.
#
# SERVICES AT THE PIN (probed against the OS flake's locked nixpkgs
# 8c3cede7ddc26bd659d2d383b5610efbd2c7a16e — nixos/modules reads, never
# assumed):
#   * services.ollama     — enable (mkEnableOption), host default
#     "127.0.0.1" (loopback, the module re-states it as mkDefault so
#     the posture is recorded HERE — a remote-facing move stays an
#     explicit operator decision, §11.2), port 11434, home
#     /var/lib/ollama, models ${home}/models, loadModels default [ ],
#     openFirewall false; the acceleration option is REMOVED upstream
#     (the package variants pkgs.ollama-cpu/-cuda/-rocm/-vulkan own it
#     — the default pkgs.ollama rides).
#   * services.open-webui — enable, package mkPackageOption open-webui,
#     host default "127.0.0.1", port 8080, environment default carries
#     OLLAMA_API_BASE_URL = "http://127.0.0.1:11434" (the upstream
#     default already pairs it with a loopback ollama; the module
#     re-states it as mkDefault), openFirewall false.
#
# INSTALLABLE-SET RESOLUTION AT THIS PIN (probed via nix eval on
# kailash-minimal.pkgs at the pinned nixpkgs — never assumed id==attr):
#   * ollama     → pkgs.ollama     present (ollama)     — the PRIMARY
#                  home; the package rides the generated list AND the
#                  service module owns the daemon;
#   * open-webui → pkgs.open-webui present (open-webui) — the package
#                  rides the generated list; the service rides
#                  cfg.webui.enable;
#   * llama.cpp  → the generated row's attr path pkgs."llama.cpp" is
#                  MISSING at this pin (the dotted alias does not
#                  exist; the live attr is pkgs.llama-cpp, probed
#                  llama-cpp-0.6.0) — the row DROPS under the
#                  lib.attrByPath ?-guard, named here. Wiring the alias
#                  back is a NATIVE_ATTRS generator-table edit (the
#                  cross-repo kailash-packages lane) — not this
#                  module's business;
#   * text-generation-webui → bespoke row — pkgs.text-generation-webui
#                  MISSING (also python3Packages.text-generation-webui):
#                  the manifest derivation pkgs/text-generation-webui/
#                  default.nix does not exist at the manifest pin
#                  7374e7a, and the pinned packages flake exposes its
#                  pkgs/ set per-system only (flake-parts packages — no
#                  overlays.default for the OS flake to compose).
#                  GUARD-DROPPED, named here: it stays a package-list
#                  candidate the moment the overlay composes it
#                  (resolveBespoke finds it unaided);
#   * gguf-quantiser → bespoke row, the same situation ("planned
#                  first-party CLI wrapping llama.cpp quantize
#                  workflows" per its manifest row). GUARD-DROPPED,
#                  named here.
#
# TINY TEST MODEL (ko#112, "documented tiny test model") — the module
# NEVER auto-pulls: services.ollama.loadModels stays empty (upstream
# default; no activation script fetches weights — model storage stays
# /var/lib/ollama/models). The operator step on an enabled host:
#
#   ollama pull qwen2.5:0.5b     # ~400 MB, sub-1B chat model
#   ollama run  qwen2.5:0.5b 'Say hi'
#
# (smollm2:360m is the smaller alternative — any sub-1B quant fits a
# lab VM.) The VM acceptance asserting the prompt COMPLETES is the VM
# wave's item (KA-08.5, ko#109) — NOT this module.
#
# MLX (the Apple-silicon ML framework): STRETCH, documented here, not
# core v1 (ko#112): no MLX manifest row exists at this pin (probed
# tools.yaml — zero MLX rows). Revisit post-v1 as a native manifest row
# when a packaging lane picks it up.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kailash.layers.ops.categories.o-04;

  # The generator's committed emit = pure structure (no package attrs).
  generated =
    (import ./generated/o-04-local-llm-inference-labs.nix {
      inherit lib;
    }).o-04-local-llm-inference-labs;

  # Resolver, §4.5: every attr path ?-guarded (green eval at revisions
  # where the overlay is absent, a native attr moves — the llama.cpp
  # dotted alias — or a bespoke derivation has not landed yet).
  resolveNative = path:
    if lib.attrByPath path null pkgs != null then [ (lib.getAttrFromPath path pkgs) ] else [ ];
  resolveBespoke = row:
    if lib.attrByPath [ row.id ] null pkgs != null
    then [ (lib.getAttrFromPath [ row.id ] pkgs) ]
    else [ ];

  # The manifest-driven install set = the generated rows resolved
  # (ollama + open-webui at this pin; the drops live in the header
  # record above). Hosts compose/append on the spine option; never
  # redefine — never a config-assignment of cfg.packages back into the
  # tree (mkIf self-assignment re-enters the layers merge
  # mid-collection, eval-probed on the O-1 module).
  installSet = lib.flatten
    (map resolveNative generated.native ++ map resolveBespoke generated.bespoke);
in
{
  # EXTRA sibling member only (KA-09.3). enable + packages are the §4.5
  # baseline members the layer tree declares (modules/base/layer-tree.nix);
  # mkIf cfg.enable drives the install + the services below.
  options.kailash.layers.ops.categories.o-04 = {
    webui = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Stand up the open-webui chat UI against the local ollama
          through the UPSTREAM services.open-webui module, pointed at
          the loopback Ollama API (the ko#112 acceptance pair).
          Default ON with the category — the category switch is the
          opt-in; this sub-toggle turns the UI off for an engines-only
          host. Category OFF ⇒ nothing rises, toggle or not.
        '';
      };
    };
  };

  config = {
    # The manifest-driven install set (native rows resolved on the
    # pinned nixpkgs + the bespoke overlay rows when the overlay is
    # composed; the generator + drift check own the regeneration).
    kailash.layers.ops.categories.o-04.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default.
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;

    # Ollama — the PRIMARY home (manifest row, probed). The category
    # switch IS the opt-in: mkIf cfg.enable hard-enables (mkDefault on
    # enable would let an empty config argue the daemon down — the
    # service must follow the category, period). Loopback bind default
    # (upstream 127.0.0.1:11434, re-stated as mkDefault so the posture
    # is recorded HERE and an operator override stays clean). The
    # module NEVER auto-pulls: loadModels stays empty — the tiny-model
    # pull is an operator step (the header note documents it).
    services.ollama = lib.mkIf cfg.enable {
      enable = true;
      host = lib.mkDefault "127.0.0.1";
    };

    # Open WebUI — the chat front-end over the local ollama (ko#112):
    # rides the UPSTREAM services.open-webui module, loopback host
    # default, pointed at the loopback Ollama API. Double-keyed:
    # cfg.enable AND cfg.webui.enable (the sub-toggle's OFF wins for an
    # engines-only host). VM reachability (the open-webui↔ollama round
    # trip inside the platform VM) is the VM wave's item (KA-08.5,
    # ko#109) — this module stands up the services, the VM asserts the
    # reachability.
    services.open-webui = lib.mkIf (cfg.enable && cfg.webui.enable) {
      enable = true;
      host = lib.mkDefault "127.0.0.1";
      environment.OLLAMA_API_BASE_URL = lib.mkDefault "http://127.0.0.1:11434";
    };
  };
}
