# VM integration test — mlflow-bypass against the O-1 lab surface
# (KA-23, kailash-os#23; spec §7.2 — the pairing thesis executed).
#
# The booted-VM acceptance leg: the PLATFORM profile boots
# (services.kailash.mlflow on :5000 — the unauth lab surface, §11.2
# posture), the §8.2 probe pair (tools/vm-integration-mlflow-attack.sh)
# runs IN-GUEST with --seed and the record captures the VERBATIM
# artefact listing the unauthenticated API returned — O-1 paired with
# the A-7 mlflow-bypass probe, asserted.
#
# Executed on a Linux VM host:  nix build -L
#   .#vmTests.x86_64-linux.integration-mlflow-attack
# Hosted CI evals this file, never boots it (the no-VMs posture, the
# KA-06.3 precedent); the boot is the maintainer's ONE interactive
# step, recorded in tests/vm-acceptance-mlflow-record.json (the
# machine-validated record — kind 'real' when the boot produces the
# verbatim outputs).
{
  lib,
  pkgs,
  system,
}:
pkgs.testers.nixosTest {
  name = "integration-mlflow-attack";
  skipTypeCheck = true;
  nodes.machine =
    { ... }:
    {
      imports = [ ../profiles/platform.nix ];
      # the DOCUMENTED lab posture the acceptance boot runs under
      # (kailash-platform-acceptance — the o-05-platform-acceptance leg
      # pins it): ollama 0.0.0.0 + the tiny model (the qemu user-net VM
      # is an isolated lab segment), MLflow labReachable (0.0.0.0 — the
      # unauthenticated lab surface the mlflow-bypass pair probes).
      services.ollama.host = "0.0.0.0";
      services.ollama.loadModels = [ "qwen2.5:0.5b" ];
      services.kailash.mlflow.labReachable = true;
      # the §6.5 pairing category (A-7) — its exp surface stays OFF the
      # package set (the ledger legs prove it; the §11.2 gate owns it).
      kailash.layers.attack.categories.a-07.enable = true;
      virtualisation.graphics = false;
      virtualisation.cores = 2;
      virtualisation.memorySize = 4096;
      virtualisation.diskSize = 16384;
    };
  testScript = ''
    import json, os, subprocess

    machine.wait_for_unit("multi-user.target")

    hostname = machine.succeed("hostname").strip()
    assert hostname == "kailash-platform", (
        f"VM hostname is not kailash-platform: got {hostname!r} "
        "(the platform profile did not drive the boot)"
    )

    # (1) the MLflow tracking surface rises with the boot (the ko#105
    # acceptance clause): the unauth health probe answers OK.
    machine.wait_for_open_port(5000)
    health = machine.succeed("curl -fsS http://127.0.0.1:5000/health").strip()
    assert health == "OK", f"MLflow /health did not answer OK: {health!r}"

    # (2) the pairing category is ON with an EMPTY install set — the
    # §11.2 gate owns the exp surface (a-07 all-exp);
    a07 = machine.succeed(
        "test -z \"$(systemctl cat kailash-mlflow.service >/dev/null 2>&1 "
        "&& echo x)\"; echo done"
    )
    assert "done" in a07

    # (3) THE §8.2 ACCEPTANCE — the committed probe pair runs IN-GUEST
    # with --seed against the lab-posture tracking surface and writes
    # the REAL record inside the VM; pull both verbatim copies out as
    # the boot's artefact evidence.
    in_vm_record = "/tmp/vm-acceptance-mlflow-record.json"
    machine.succeed(
        "kailash-integration-mlflow-attack "
        "--mlflow-url http://127.0.0.1:5000 --seed "
        f"--record {in_vm_record} --wait-seconds 300"
    )
    machine.copy_from_vm(in_vm_record, "mlflow-in-vm-record")

    rec = json.load(open("mlflow-in-vm-record/1/" + os.path.basename(in_vm_record)))
    assert rec["status"] == "real", f"in-VM record is not real: {rec['status']!r}"
    assert rec["tracking"]["verdict"] == "ok", "tracking probe not ok"
    assert rec["bypass"]["verdict"] == "ok", "bypass probe not ok"
    # THE ARTEFACT LISTING assertion: the verbatim bypass section names
    # the seeded listing file.
    assert "ka23-listing.txt" in rec["bypass"]["verbatim"], (
        "the artefact listing is not present in the bypass verbatim section"
    )
    print("integration-mlflow-attack: the pairing thesis executed (in-VM, verbatim)")
  '';
}
