# Layer OPS — O-2 Compute & Serving Infrastructure (KA-08.2, ko#106; plan
# §3.5, §9 Phase 3). The §4.5 category-module shape:
#
#   options.kailash.layers.ops.categories.o-02-compute-serving-infrastructure = {
#     enable   — the category switch (mkEnableOption, default OFF);
#     packages — the generated, manifest-driven install set (§4.5; hosts
#                append; never redefine);
#     k3s      — the k3s service toggle: rides the UPSTREAM services.k3s
#                module (probed at the pin) — never a first-party server
#                derivation here;
#     podman   — the rootless container substrate: rides the upstream
#                virtualisation.podman module (dockerCompat default ON —
#                the docker-socket compatibility the docker-backed lab
#                tooling expects; the ko#111 Shape-3 substrate);
#   };
#   config (mkIf enable) installs the set and applies the toggles.
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
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kailash.layers.ops.categories.o-02-compute-serving-infrastructure;

  # The generator's committed emit = pure structure (no package attrs).
  generated =
    (import ./generated/o-02-compute-serving-infrastructure.nix {
      inherit lib;
    }).o-02-compute-serving-infrastructure;

  # Resolver, §4.5: every attr path ?-guarded (green eval at revisions
  # without the overlay or where a native attr moves).
  resolveNative = path:
    if lib.attrByPath path null pkgs != null then [ (lib.getAttrFromPath path pkgs) ] else [ ];
  resolveBespoke = row:
    if lib.attrByPath [ row.id ] null pkgs != null
    then [ (lib.getAttrFromPath [ row.id ] pkgs) ]
    else [ ];

  # The install set = the generated rows resolved (the OPTION DEFAULT —
  # hosts append via the typed option; NEVER a config-assignment of
  # cfg.packages back into the tree — re-enters the layers merge,
  # eval-probed at this pin).
  o-02-packages = lib.flatten
    (map resolveNative generated.native ++ map resolveBespoke generated.bespoke);
in
{
  options.kailash.layers.ops.categories.o-02-compute-serving-infrastructure = {
    enable = lib.mkEnableOption ''
      the O-2 Compute and Serving Infrastructure category (KA-08.2): the
      container/orchestration substrate (k3s, minikube, kind, podman,
      nvidia-container-toolkit, vllm) plus the docker-socket compatibility
      substrate. The serving stacks (tgi, torchserve, kserve, ray, triton)
      are manifest module rows — they NEVER enter this package set; their
      service modules own them. ollama/llama.cpp ride the O-4 category
      (their manifest primary — §4.5 cross-refs). Nothing installs or
      listens until enabled (§4.5 opt-in by default)
    '';

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = o-02-packages;
      defaultText = lib.literalExpression ''
        manifest-driven (modules/ops/generated + the generator's emit)
      '';
      description = ''
        The O-2 category install set: generated from the pinned manifest
        (§4.5). Hosts append; never redefine.
      '';
    };

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

  config = lib.mkIf cfg.enable {
    environment.systemPackages = cfg.packages;

    # The substrates ride the UPSTREAM NixOS modules (probed at the pin);
    # both default OFF and are gated by THIS category's enable plus their
    # own switches — the category installs the CLI tooling; the daemons
    # only rise when the operator declares them.
    services.k3s = lib.mkIf cfg.k3s.enable {
      enable = true;
      role = lib.mkDefault "server";
    };

    virtualisation.podman = lib.mkIf cfg.podman.enable {
      enable = true;
      dockerCompat = lib.mkDefault cfg.podman.dockerCompat;
    };
  };
}
