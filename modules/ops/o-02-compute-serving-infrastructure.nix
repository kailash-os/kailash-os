# Layer OPS — O-2 Compute & Serving Infrastructure (KA-08.2, ko#106; plan
# §3.5, §9 Phase 3). The §4.5 category module, config-only on the §3.6 typed
# spine (modules/base/layer-tree.nix — the per-id option-decl tree; the
# same mount the exemplar modules/classic/c-01-information-gathering.nix
# defines). The spine owns enable + packages at
# kailash.layers.ops.categories.o-02 (the SHORT manifest id — the tree
# keys categories by the §3.6 census ids; the module FILE keeps the
# manifest's long id); this module declares only its EXTRA sibling members
# via the bare-tree sibling pattern (the same shape the O-3 backends mixin
# uses) and consumes the spine members:
#
#   enable   — the category switch (spine default false; profiles opt in):
#              the O-2 Compute and Serving Infrastructure category — the
#              container/orchestration substrate CLI tooling (k3s, minikube,
#              kind, podman, nvidia-container-toolkit, vllm). The serving
#              stacks (tgi, torchserve, kserve, ray, triton) are manifest
#              module rows — they NEVER enter this package set; their
#              service modules own them. ollama/llama.cpp ride the O-4
#              category (their manifest primary — §4.5 cross-refs). Nothing
#              installs until enabled (§4.5 opt-in by default).
#   packages — the generated, manifest-driven install set (config-assigned
#              below; hosts compose/append on the spine option — never
#              redefine).
#
#   EXTRA sibling members (declared HERE on the same tree path, merging
#   without structural change):
#     k3s    — the k3s service toggle: rides the UPSTREAM services.k3s
#              module (probed at the pin) — never a first-party server
#              derivation here;
#     podman — the rootless container substrate: rides the upstream
#              virtualisation.podman module (dockerCompat default ON —
#              the docker-socket compatibility the docker-backed lab
#              tooling expects; the ko#111 Shape-3 substrate).
#
# Routing contracts (same shape as the O-1 module, §4.5):
#   * module-status rows (tgi, torchserve, kserve, ray,
#     triton-inference-server) NEVER reach a package list — the row's own
#     service modules own them (their wave items land those modules;
#     manifest packaging.status is the routing record). vllm IS a NATIVE
#     manifest row at this pin → its CLI package rides the generated list.
#   * ollama + llama.cpp are NOT here: their manifest PRIMARY is
#     o-04-local-llm-inference-labs (this category is a secondary tag —
#     cross-references resolve via secondary tags, never duplicate
#     installs, §4.5); the packages land with the O-4 wave item.
#   * safety.level == "exp" rows would NEVER land here (§11.2 double-key
#     gate; no o-02 row is exp at this pin).
#
# DATA CONTRACT: same as the O-1 module (generated manifest-driven
# structure in modules/ops/generated/, pure emit, CI drift-checked every
# PR by checks.o-02-generated-drift; resolution ?-guarded HERE).
{ config, lib, pkgs, ... }:

let
  cfg = config.kailash.layers.ops.categories.o-02;

  # The generator's committed emit = pure structure (no package attrs).
  generated =
    (import ./generated/o-02-compute-serving-infrastructure.nix {
      inherit lib;
    }).o-02-compute-serving-infrastructure;

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
  # eval-probed at this pin).
  installSet = lib.flatten
    (map resolveNative generated.native ++ map resolveBespoke generated.bespoke);
in
{
  # EXTRA sibling members only (KA-08.2). enable + packages are the §4.5
  # baseline members the layer tree declares (modules/base/layer-tree.nix);
  # mkIf cfg.enable drives the install + the substrate toggles below.
  options.kailash.layers.ops.categories.o-02 = {
    k3s = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Stand up the k3s server (single-node lab default — role
          "server", upstream default) through the UPSTREAM services.k3s
          module — never a first-party server derivation here. Default
          OFF (the §11.2 no-auto-start posture: nothing listens until the
          operator declares it).
        '';
      };
    };

    podman = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable the rootless podman substrate through the upstream
          virtualisation.podman module (dockerCompat default ON — the
          docker-socket compatibility; the ko#111 Shape-3 substrate).
          Default OFF.
        '';
      };
      dockerCompat = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Provide a docker shim via podman (upstream
          virtualisation.podman.dockerCompat). Default ON when podman is
          enabled — the compatibility the docker-backed lab tooling
          expects; set false for a strict podman-only substrate.
        '';
      };
    };
  };

  config = {
    # The manifest-driven install set (native rows resolved on the pinned
    # nixpkgs + the bespoke overlay rows when the overlay is composed; the
    # generator + drift check own the regeneration).
    kailash.layers.ops.categories.o-02.packages = installSet;

    # The §4.5 install config: nothing on PATH until the category switch
    # is ON — opt-in by default.
    environment.systemPackages = lib.mkIf cfg.enable cfg.packages;

    # The substrates ride the UPSTREAM NixOS modules (probed at the pin);
    # both default OFF and are gated by THIS category's enable plus their
    # own switches — the category installs the CLI tooling; the daemons
    # only rise when the operator declares them.
    services.k3s = lib.mkIf (cfg.enable && cfg.k3s.enable) {
      enable = true;
      role = lib.mkDefault "server";
    };

    virtualisation.podman = lib.mkIf (cfg.enable && cfg.podman.enable) {
      enable = true;
      dockerCompat = lib.mkDefault cfg.podman.dockerCompat;
    };
  };
}