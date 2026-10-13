# The PLATFORM profile (KA-08.5, kailash-os#109; plan §9 Phase 3 — "the
# parent's acceptance run: platform-profile VM boots, working ollama (tiny
# model completes a prompt), MLflow reachable on :5000").
#
# Composition: the CORE substrate floor (profiles/minimal.nix — modules
# tree, bootable-VM floor) + exactly the two OPS categories the platform
# acceptance names — O-1 MLOps (whose service module stands up MLflow)
# and O-4 Local LLM & Inference Labs (ollama). Nothing else installs:
# the acceptance is about the TWO services, not breadth.
#
# Services on this profile (the ko#105/#112 pair — both loopback-bound
# by their module defaults, §11.2):
#
#   ollama — services.ollama, 127.0.0.1:11434 (the o-04 module
#            hard-enables the service with its category switch and
#            re-states the loopback host default). THE ACCEPTANCE
#            MODEL IS AN OPERATOR STEP: the o-04 module NEVER
#            auto-pulls (services.ollama.loadModels stays at the
#            upstream empty default), so the prompt check needs the
#            sub-1B model pulled INSIDE the VM first (the o-04 module
#            header's documented step: `ollama pull qwen2.5:0.5b`). The
#            attempted commands ride the harness runbook
#            (tools/vm-acceptance-harness.sh) and the record
#            (tests/vm-acceptance-record.json).
#
#   MLflow — services.kailash.mlflow: the tracking server on :5000 (the
#            ko#105 acceptance clause), loopback bind by the module's
#            host default, sqlite backend under /var/lib/kailash-mlflow.
#
# NOT a product profile: it exists to carry the platform acceptance VM
# (its toplevel is the exercise target) the same way the KA-28.0
# QEMU-primary decision names a per-profile image surface (Wave-6-first;
# images/ISOs are the images-wave items, never this acceptance). The
# check leg (o-05-platform-services — the SAME-eval pattern of every
# §4.5 leg) asserts the composition: both services ON, both loopback,
# :11434/:5000, MLflow's systemd unit wired, and the webui sub-toggle
# OFF here (an engines-only platform host — the open-webui↔ollama
# pairing stays with redteam-ai, which carries ko#112).
#
# KA-23 (kailash-os#23): the mlflow-bypass integration joins this
# profile — the §8.2 pairing-thesis acceptance (boot-wait + the two
# mlflow-bypass probe pair: the unauth experiments/search + the unauth
# artefact listing) rides TOOLS/vM-INTEGRATION (the same pending-vm
# record discipline as its parent acceptance).
{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./minimal.nix
  ];

  networking.hostName = lib.mkForce "kailash-platform";

  # The acceptance categories (the §4.5 category switches ARE the
  # opt-in; FALSE defaults stay on the CORE floor untouched):
  kailash.layers.ops.categories.o-01.enable = lib.mkDefault true;

  # ---- the MLflow tracking server (the ko#105 clause) ------------------
  # The o-01 service module enables it with the category; the port is
  # the acceptance clause, re-stated for readability. Bind host stays
  # the module default (127.0.0.1) — a hostfwd port-forward from the
  # qemu host reaches it ONLY when an operator moves the bind off the
  # loopback or tunnels it; the canonical probe runs INSIDE the VM.
  services.kailash.mlflow = {
    enable = lib.mkDefault true;
    port = lib.mkDefault 5000;
  };

  # ---- the ollama daemon (the o-04 category switch) --------------------
  kailash.layers.ops.categories.o-04.enable = lib.mkDefault true;
  # Loopback bind: the o-04 module re-states the upstream default under
  # its own mkIf cfg.enable — re-stating HERE would race the category
  # config for no value; the binding is asserted by the check leg
  # instead (the o-04-services shape).

  # open-webui OFF for an engines-only platform host (the acceptance
  # checks ollama + MLflow only; the webui pairing lives on
  # redteam-ai — ko#112's reachability item).
  kailash.layers.ops.categories.o-04.webui.enable = lib.mkDefault false;

  # ---- the §8.2 mlflow-bypass acceptance harness (KA-23) ----------------
  # On the VM's PATH for the in-guest canonical run: the probe pair
  # rides the booted tracking surface (the same §11.2-postured,
  # unauthenticated MLflow API this host exposes — the acceptance
  # pairing, not a new service).
  environment.systemPackages = [
    (pkgs.callPackage (
      {
        stdenv,
        lib,
        makeWrapper,
      }:
      stdenv.mkDerivation {
        pname = "vm-integration-mlflow-probe-pair";
        version = "unstable-2026-10-13";
        src = ../tools/vm-integration-mlflow-attack.sh;
        nativeBuildInputs = [ makeWrapper ];
        dontUnpack = true;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/kailash-integration-mlflow-attack
          chmod +x $out/bin/kailash-integration-mlflow-attack
          patchShebangs $out/bin/kailash-integration-mlflow-attack
          wrapProgram $out/bin/kailash-integration-mlflow-attack \
            --prefix PATH : ${
              lib.makeBinPath [
                pkgs.coreutils
                pkgs.curl
                pkgs.jq
                pkgs.python3
                pkgs.gnugrep
                pkgs.gnused
              ]
            }
        '';
        meta.mainProgram = "kailash-integration-mlflow-attack";
        meta.license = lib.licenses.mit;
      }
    ) { })
  ];
}
