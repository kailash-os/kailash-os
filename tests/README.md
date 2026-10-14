# kailash VM smoke suite — run instructions (the PENDING-VM contract home)

Every `see tests/README.md` reference resolves here. This file exists
because the test comment headers and `flake.nix` cite it as the home of
the run instructions for the VM smoke suite (issue kailash-os#190).

## The posture

Hosted CI **evals** these legs, never **boots** them (the no-VMs posture,
KA-06.3): `nix flake check` exercises every leg's eval and the option
tree, and the eval-side contract check
(`checks.x86_64-linux.classic-vm-smoke-contract`) binds the suite to the
[spec §3.5](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#35-the-category-module-contract) module options — so a module lane that moves a reviewed row REDs CI
the day it lands. The BOOT itself runs wherever a Linux VM host is:
a maintainer's box or CI with KVM.

## The legs (compiled from the flake's `vmTests.x86_64-linux` output)

| Leg | What it asserts |
| --- | --- |
| `c-01` | information-gathering PATH rows + flagship by name (nmap) |
| `c-02` | vulnerability-analysis PATH rows + flagship by name (sqlmap, nikto) |
| `c-04` | database-assessment PATH rows (psql, redis-cli ride the server packages) |
| `c-06` | reverse-engineering PATH rows + flagship by name (ghidra) |
| `full-profile-boot` | the whole CLASSIC floor boots with all four categories enabled |
| `integration-mlflow-attack` | the platform profile boots and the mlflow-bypass probe pair runs IN-GUEST with `--seed`; the in-VM record is pulled out and asserted (`status: real`, both probes ok, the artefact listing names `ka23-listing.txt`) |

## Running a leg

```sh
nix build -L .#vmTests.x86_64-linux.<leg>     # build + boot + assert
result/bin/nixos-test-driver                  # only if re-driving interactively
```

The build substitutes everything the hosted runs already produced
(the kailash cachix cache warms the closure); a leg build is minutes,
not hours.

## Records (the acceptance tripwires)

* `tests/vm-acceptance-record.json` — the KA-08.5 platform acceptance
  (ollama prompt + MLflow health). Kind `pending-vm` until the
  maintainer's interactive qemu boot records verbatim outputs; the
  verifier (`tools/vm-acceptance-verify.py`) fails CI on any kind it
  does not allow, and on an "ok" verdict with no verbatim output behind it.
* `tests/vm-acceptance-mlflow-record.json` — the KA-23
  integration-mlflow-attack acceptance (same discipline, verifier
  `tools/vm-integration-mlflow-verify.py`; the probe pair lives in
  `tools/vm-integration-mlflow-attack.sh` and runs in-guest via the
  `kailash-integration-mlflow-attack` PATH binary the platform profile
  ships).

Both verifiers run in CI every PR (`checks.x86_64-linux.o-05-platform-vm-record`,
`checks.x86_64-linux.integration-mlflow-attack-record`) — a hand-typed
ok with no verbatim output behind it fails CI.
