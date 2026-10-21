# O-3 docker-wrapper stores — wrapper posture (KA-09.2)

The kailash specification
([§4.3, Shape 3](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#43-bespoke-derivations-the-patterns))
defines the **docker-wrapper** packaging shape: a service that ships as an
honest wrapper module around a container image, never as a pretence of a
native derivation. This document records the posture of every O-3 store
that rides the wrapper shape, per the module's `backends` option
(`kailash.layers.ops.categories.o-03.backends`):

- **weaviate** (BSD-3-Clause OR LicenseRef-Weaviate-Community) —
  image `semitechnologies/weaviate:1.39.2`, container
  `kailash-o-03-weaviate`, HTTP 8080 / gRPC 50051 (container-internal
  defaults; the wrapper exposes nothing extra — a port exposure is an
  operator override on the container attrset, loopback-bound by the
  podman substrate).

- **milvus** (Apache-2.0) — image `milvusdb/milvus:v2.6.7`, container
  `kailash-o-03-milvus`, gRPC 19530 / HTTP 9091 (container-internal
  defaults; single-node standalone mode as the wrapper default).

- **elasticsearch** (AGPL-3.0-only OR SSPL-1.0 OR ELv2 at the 7.17 line)
  — image `docker.elastic.co/elasticsearch/elasticsearch:7.17.27`,
  container `kailash-o-03-elasticsearch`, HTTP 9200 (single-node
  discovery; the triple licence at the pin is the manifest's record, not
  a re-licence).

## The wrapper contract (what "honest" means)

1. **Virtualisation substrate, not a nix package.** Each wrapper is one
   `virtualisation.oci-containers.containers.<name>` entry on the
   `podman` backend the module sets at the category boundary (`backend =
   "podman"` — rootless default; never a bare global
   `virtualisation.docker`/`virtualisation.podman` enable, never a nix
   package). The image ref is pinned in the module
   (`modules/ops/o-03-vector-stores-retrieval.nix`); the pull happens at
   service start, never at eval.

2. **Operator-started (no-auto-start posture,
   [spec §9.2](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#92-safety-defaults-module-basesafety-defaultsnix)).**
   Every wrapper container declares `autoStart = false`: the store container
   is present and configured in the closure, and the operator starts it
   explicitly (`systemctl start kailash-o-03-<store>`). A heavy vector
   store never starts on its own.

3. **Attack surface stays native
   ([kailash-os#111](https://github.com/kailash-os/kailash-os/issues/111) clause).**
   The wrappers serve the O-3 operational posture only. The attack-side
   tooling that targets these stores (A-7) is natively derived in the
   packages repo and trains against the reachable stores. The wrapper
   shape never hides the absence of a derivation for offensive tooling.
   (A pre-purge A-7 example row was a phantom-upstream row removed by the
   [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)
   audit — the native-derivation clause itself stands; the registry
   records the removed name:
   [the phantom-upstream registry](https://github.com/kailash-os/kailash-os/issues/210).)

4. **Eval-time honesty.** The wrappers are eval-asserted
   (`o-03-backends-containers` in the root flake): container set,
   backend (`podman`), and image pins are checked against this
   document's posture; the per-id posture rows here are the source the
   check names.

## Pull choices

The images pull from their upstream registries at service start:

| Store | Registry | Pull policy |
| --- | --- | --- |
| weaviate | docker.io (semitechnologies) | at first `systemctl start`, cached afterwards |
| milvus | docker.io (milvusdb) | at first `systemctl start`, cached afterwards |
| elasticsearch | docker.elastic.co | at first `systemctl start`, cached afterwards |

An air-gapped lab pre-loads the image with `podman load`. The wrapper
module is not coupled to a mirror posture (that is an operator decision,
not a distribution default).
