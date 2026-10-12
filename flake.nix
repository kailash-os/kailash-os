{
  description = "Kailash OS - NixOS for AI Security";

  nixConfig = {
    extra-substituters = "https://kailash.cachix.org";
    extra-trusted-public-keys = "kailash.cachix.org-1:HnASOtfS7XRjQBrH9umnPljPRjvHeJKDvwZDYXt+sKM=";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    kailash-packages = {
      url = "github:kailash-os/kailash-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # optional, commented per §4.4: determinate (nix.nixosModules),
    # nixified-ai (GPU variants land per-package Shape 4, never global)
  };

  outputs = { self, nixpkgs, kailash-packages, flake-parts
            , nixos-generators, disko, sops-nix, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowInsecurePredicate = p: true;  # pentest tooling posture (RedNix heritage)
        };
        # The packages overlay wires in when the overlay flake grows
        # overlays.default (packaging items); guarded so host evaluation
        # stays green at revisions without it.
        overlays = lib.optionals
          (kailash-packages ? "overlays" && (kailash-packages.overlays ? "default"))
          [ kailash-packages.overlays.default ];
      };
    in
    {
      nixosModules.kailash = { imports = [ ./modules ]; };

      # Host namespace: the minimal profile — the CORE substrate with zero
      # categories enabled (KA-01.3). Higher profiles layer on top of it.
      nixosConfigurations.kailash-minimal = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [ ./profiles/minimal.nix ];
      };

      # ---- Safety-gate fixtures (KA-18.1, os#92) --------------------------
      #
      # Synthetic hosts that drive the lab-mode gate's RED/GREEN:
      # `kailash-fixture` (lab gate OFF) and `kailash-fixture-on` (gate ON)
      # both carry a synthetic safety:exp tool. Their
      # `config.kailash.safety.manifests` list carries BOTH the pinned
      # packages manifest through the flake input (never a hand-copy; the
      # current pin is census-empty, so it contributes nothing vacuously)
      # AND the in-repo synthetic-fixture manifest whose exp rows exist
      # regardless of pin staleness. The fixtures are not product profiles
      # and never enter nixosConfigurations beyond the checks.

      nixosConfigurations.kailash-fixture = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          ./tests/safety-fixture.nix
          {
            networking.hostName = lib.mkForce "kailash-fixture";
            kailash.safety.manifests = [
              (kailash-packages.outPath + "/manifest/tools.yaml")
              ./tests/safety-fixture-manifest.yaml
            ];
          }
        ];
      };

      nixosConfigurations.kailash-fixture-on = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          ./tests/safety-fixture.nix
          {
            networking.hostName = lib.mkForce "kailash-fixture-on";
            kailash.labMode = true;
            kailash.safety.manifests = [
              (kailash-packages.outPath + "/manifest/tools.yaml")
              ./tests/safety-fixture-manifest.yaml
            ];
          }
        ];
      };

      # Eval gate + the safety-gate checks, exercised by `nix flake check`.
      checks.${system} = {
        kailash-minimal-toplevel =
          self.nixosConfigurations.kailash-minimal.config.system.build.toplevel;

        # Gate leg 1 (negative, the acceptance run): the fixture exp tool
        # refuses to run bare AND refuses with the shell key alone — the
        # refusal names BOTH keys (host option labMode + KAILASH_LAB_MODE).
        # RED stub: the tool runs unwrapped → the check fails on the first
        # branch until the GREEN commit lands the wrapper mechanism.
        safety-exp-gate-run = pkgs.runCommand "safety-exp-gate-run"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          T=${self.nixosConfigurations.kailash-fixture.config.system.build.toplevel}
          echo "--- fixture exp tool without lab mode (gate must refuse)"
          if "$T/sw/bin/kailash-fixture-exp" > run.out 2>&1
          then
            echo "the fixture exp tool ran bare (no wrapper)"; cat run.out
            exit 1
          fi
          grep -q "KAILASH_LAB_MODE" run.out || { echo "refusal does not name the shell key"; cat run.out; exit 1; }
          grep -q "labMode" run.out || { echo "refusal does not name the host option"; cat run.out; exit 1; }
          cat run.out
          echo "--- fixture exp tool with KAILASH_LAB_MODE=1 (still refuses: host key off)"
          if KAILASH_LAB_MODE=1 "$T/sw/bin/kailash-fixture-exp" > run2.out 2>&1
          then
            echo "the shell key alone opened the gate"; cat run2.out
            exit 1
          fi
          cat run2.out
          echo "safety-exp-gate-run: OK"
          touch $out
        '';

        # Gate leg 2 (positive): on the lab-on host the tool runs when BOTH
        # keys are set (host option true + KAILASH_LAB_MODE=1).
        safety-exp-gate-on = pkgs.runCommand "safety-exp-gate-on"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          T=${self.nixosConfigurations.kailash-fixture-on.config.system.build.toplevel}
          echo "--- lab-on host: tool runs when BOTH keys are set"
          OUT="$(KAILASH_LAB_MODE=1 "$T/sw/bin/kailash-fixture-exp" 2>&1)"
          echo "$OUT"
          case "$OUT" in
            *FIXTURE-EXP-TOOL-RAN*) : ;;
            *) echo "gate did not open with both keys set"; exit 1 ;;
          esac
          echo "safety-exp-gate-on: OK"
          touch $out
        '';

        # Parity validator leg (the failure mode os#95 names, OS side): the
        # committed tool reads the expected exp surface from a manifest
        # (PyYAML; --manifest-file) and requires the host's committed wrap
        # report to cover every id — with a behavioral probe per claimed
        # wrap (gate script present, both key names in it). RED stub: the
        # stub module wraps nothing → required exp ids uncovered. GREEN:
        # exact, behavior-verified coverage proves the harness-bites clause.
        safety-exp-wrap-parity = pkgs.runCommand "safety-exp-wrap-parity"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          python3 ${./tools/safety-exp-wrap.py} \
            --manifest-file ${./tests/safety-fixture-manifest.yaml} \
            --wrapped-file ${self.nixosConfigurations.kailash-fixture.config.kailash.safety.wrappedReportFile} \
            kailash-fixture
          touch $out
        '';

        # Cross-check leg: an independent PyYAML parse of the SAME fixture
        # manifest the module's scan reads — the scan (Nix) and this parse
        # (Python) must agree that the synthetic exp rows exist, so scan
        # drift is a loud CI failure, never a silent vacuous pass.
        safety-require-exp-fixture = pkgs.runCommand "safety-require-exp-fixture"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          got="$(python3 - ${./tests/safety-fixture-manifest.yaml} <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
ids = [t["id"] for t in doc["tools"] if (t.get("safety") or {}).get("level") == "exp"]
print(",".join(ids))
PY
)"
          test -n "$got"
          echo "$got" | tr ',' '\n' | grep -qx "kailash-safety-fixture"
          echo "manifest exp ids: $got"
          touch $out
        '';

        # Real-surface parity + drift alarm (KA-19.2, kailash-os#95).
        #
        # The parity gate proper (safety-exp-wrap-parity above) checks the
        # fixture host's wrap report against the FIXTURE manifest — the
        # synthetic exp id is covered by construction. This leg is the
        # REAL manifest's drift alarm: it reads the pinned packages
        # manifest (through the flake input, never a hand-copy), runs the
        # vendored byte-identical KA-19.1 generator
        # (tools/gen-exp-wrap.py) against it, and requires the emitted
        # exp surface to equal the committed snapshot
        # tests/expected-exp-ids.txt — a packages-side merge that moves
        # the exp surface turns this leg red with `exp surface drifted`
        # until the snapshot is regenerated in the same cycle.
        # Cross-checks inside the leg:
        #   * the Nix scan (the module's manifestExpIds over the pinned
        #     manifest, the same scanToolsYaml the gate installs from)
        #     must equal the generator's PyYAML emit for the same file —
        #     scanner-vs-generator dual-parse agreement (the
        #     safety-require-exp-fixture contract, lifted to the real
        #     pin);
        #   * the fixture host's OWN wrap report still covers its own
        #     declared exp id (wrappedIds ⊇ manifestExpIds of the
        #     fixture manifest) — the os#95 negative case stays wired
        #     next to the real-surface leg.
        # NOT a coverage gate on the real exp ids against the fixture
        # host: the fixture host declares only its synthetic tool; real
        # coverage gates on the wrapped host's own declared surface.
        safety-exp-parity-real = pkgs.runCommand "safety-exp-parity-real"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          MANIFEST=${kailash-packages.outPath + "/manifest/tools.yaml"}
          SNAPSHOT=${./tests/expected-exp-ids.txt}
          GOT="$(python3 ${./tools/gen-exp-wrap.py} --manifest-file "$MANIFEST")"
          COUNT="$(python3 -c 'import json,sys; print(len(json.load(sys.stdin)["exp_ids"]))' <<<"$GOT")"
          echo "real-manifest exp rows emitted from the pinned manifest: $COUNT"
          test -n "$COUNT" && test "$COUNT" -gt 0 || { echo "safety-exp-parity-real: FAIL: generator emitted no exp rows from the pinned manifest"; exit 1; }
          # Scan-vs-generator agreement: the module's eval-time scan of
          # the SAME pinned manifest (manifest order, deduplicated) must
          # equal the generator's sorted emit for the same file. The
          # fixture's own synthetic exp id is filtered out of the scan —
          # it rides the fixture manifest, never the packages pin.
          SCAN="$(echo "${
            lib.concatStringsSep ","
              (lib.filter (i: i != "kailash-safety-fixture")
                self.nixosConfigurations.kailash-fixture.config.kailash.safety.manifestExpIds)
          }" | tr ',' '\n' | grep -c . || true)"
          echo "module scan counted: $SCAN"
          test "$SCAN" -eq "$COUNT" || { echo "safety-exp-parity-real: FAIL: module scan ($SCAN) != generator emit ($COUNT) — scan drift"; exit 1; }
          GEN="$(python3 -c 'import json,sys; print(chr(10).join(json.load(sys.stdin)["exp_ids"]))' <<<"$GOT")"
          # Drift alarm: the emitted surface must equal the committed
          # snapshot exactly (missing AND extra ids are drift). The
          # verifier prints the delta lines on stderr and exits 1 —
          # the watched red prints them verbatim.
          if python3 -c 'import sys
gen = sorted(l for l in sys.stdin.read().splitlines() if l)
snap = sorted(l for l in open(sys.argv[1], encoding="utf-8").read().splitlines() if l and not l.startswith("#"))
missing = sorted(set(snap) - set(gen))
extra = sorted(set(gen) - set(snap))
if gen != snap:
    if missing: print("missing-from-manifest: " + ",".join(missing))
    if extra: print("new-in-manifest: " + ",".join(extra))
    sys.exit(1)
open(sys.argv[2], "w", encoding="utf-8").write(chr(10).join(gen) + chr(10))
' "$SNAPSHOT" emitted-real-snapshot.txt <<<"$GEN" >delta.out 2>drift.err
          then cp emitted-real-snapshot.txt "$out"
          else echo "safety-exp-parity-real: FAIL: exp surface drifted"; cat delta.out drift.err; exit 1
          fi
          echo "drift alarm: real exp surface matches the committed snapshot ($COUNT ids)"
          # The fixture host's own report still covers its own exp id
          # (the os#95 negative case stays wired next to the alarm).
          python3 ${./tools/safety-exp-wrap.py} \
            --manifest-file ${./tests/safety-fixture-manifest.yaml} \
            --wrapped-file ${self.nixosConfigurations.kailash-fixture.config.kailash.safety.wrappedReportFile} \
            kailash-fixture
          echo "safety-exp-parity-real: OK"
          touch $out
        '';

        # ---- No-auto-start standing audit (KA-18.2, os#93) ----------------
        #
        # The hostile fixture (lab gate ON, exp tool name, auto-starting
        # exp service) proves the scanner bites; the audit-clean leg
        # requires the finding list EMPTY on the minimal profile on every
        # PR, so a later service module that auto-starts exp tooling turns
        # CI red here. RED stub: the scanner reports nothing and the
        # hostile check fails ("autostart not caught") until the GREEN
        # commit implements the scan.

        audit-hostile-fixture = pkgs.runCommand "audit-hostile-fixture"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          found="${lib.concatStringsSep "|" self.nixosConfigurations.kailash-audit-hostile.config.kailash.audit.autoStart.violations}"
          echo "hostile fixture findings: $found"
          case "$found" in
            *exp-tool-by-audit-fixture*) ;;
            *) echo "audit-hostile-fixture: autostart not caught — the scanner must fail this fixture"; exit 1 ;;
          esac
          touch $out
        '';

        audit-auto-start-clean = pkgs.runCommand "audit-auto-start-clean"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          found="${lib.concatStringsSep "|" self.nixosConfigurations.kailash-minimal.config.kailash.audit.autoStart.violations}"
          if [ -n "$found" ]; then
            echo "audit-auto-start-clean: VIOLATIONS on kailash-minimal: $found"
            exit 1
          fi
          echo "audit-auto-start-clean: no auto-start of exp tooling on kailash-minimal"
          touch $out
        '';

        # The responsible-use statement is data: profiles and gates
        # reference docs/responsible-use.md — the file must exist and carry
        # the AU provisions the plan §11.1 names (statutes by name, never
        # invented legal text).
        responsible-use-file = pkgs.runCommand "responsible-use-file"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          f=${./docs/responsible-use.md}
          test -f "$f"
          grep -q "Cyber Security Act 2024" "$f"
          grep -q "Criminal Code Act 1995" "$f"
          grep -q "Division 474" "$f"
          echo "responsible-use-file: OK (AU provisions present, statutes by name)"
          touch $out
        '';

        # The red-team profile's gates (KA-17.1): the host's system closure
        # evaluates, and the layer intent survives composition (attack ON,
        # O-4 ON — the pairing-thesis composition).
        kailash-redteam-ai-toplevel =
          self.nixosConfigurations.kailash-redteam-ai.config.system.build.toplevel;

        # Hardened-minimal host closure (KA-17.2, os#115): the hardened
        # profile evaluates AND builds — the toplevel derivation is the
        # flake-check gate (nix flake check builds every check).
        kailash-minimal-hardened-toplevel =
          self.nixosConfigurations.kailash-minimal-hardened.config.system.build.toplevel;

        kailash-redteam-ai-options = pkgs.runCommand
          "kailash-redteam-ai-options" { } ''
          test "${toString self.nixosConfigurations.kailash-redteam-ai.config.kailash.layers.attack.enable}" = "1"
          test "${toString self.nixosConfigurations.kailash-redteam-ai.config.kailash.layers.ops.categories.o-04.enable}" = "1"
          touch $out
        '';

        # ---- Lab-gate OFF on the minimal profiles (KA-17.2, os#115) -------
        #
        # Both minimal-profile hosts must carry the lab-mode host key OFF —
        # the baseline substrate (kailash-minimal, the KA-01.3 floor) and
        # the hardened profile (kailash-minimal-hardened, the named,
        # reviewable posture this item lands). A profile or a later edit
        # that flips kailash.labMode on a minimal host turns CI red here.
        kailash-minimal-labmode-pinned = pkgs.runCommand
          "kailash-minimal-labmode-pinned" { } ''
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.labMode}" = "false" \
            || { echo "kailash-minimal must keep kailash.labMode = false"; exit 1; }
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal-hardened.config.kailash.labMode}" = "false" \
            || { echo "kailash-minimal-hardened must keep kailash.labMode = false"; exit 1; }
          touch $out
        '';

        # ---- O-3 vector stores typed surface (KA-09.1, ko#110) -------------
        #
        # Eval assertions over the typed o-03 category options: the native
        # install set (python-module chromadb + qdrant + faiss + txtai +
        # the overlay's jina-embeddings-cli when composed) is non-empty on
        # an o-03 host and services wire up (chromadb, qdrant, postgresql
        # with the pgvector extension inside its package set). RED stub
        # (KA-09.1): the assertions cannot evaluate while the typed
        # surface is missing (`o-03.packages` does not exist) - the eval
        # failure is the watched red; GREEN: the typed module and the
        # spine land and every assertion passes through the SAME eval.
        o-03-options =
          let
            o3Host = (self.nixosConfigurations.kailash-redteam-ai.extendModules {
              modules = [ { kailash.layers.ops.categories.o-03.enable = true; } ];
            });
            pgExt = o3Host.config.services.postgresql.package.installedExtensions;
          in
          pkgs.runCommand "o-03-options" { } ''
            set -- ${toString (map (p: p.pname or p.name) o3Host.config.kailash.layers.ops.categories.o-03.packages)}
            for expected in chromadb qdrant faiss txtai; do
              found=""
              for got in "$@"; do [ "$got" = "$expected" ] && found=1; done
              [ -n "$found" ] || { echo "o-03 install set missing $expected"; exit 1; }
            done
            echo "o-03 native install set: $*"
            test "${toString o3Host.config.services.chromadb.enable}" = "1" \
              || { echo "services.chromadb not wired by the o-03 module"; exit 1; }
            test "${toString o3Host.config.services.qdrant.enable}" = "1" \
              || { echo "services.qdrant not wired by the o-03 module"; exit 1; }
            echo "postgresql extensions: ${lib.concatStringsSep "," pgExt}"
            case "${lib.concatStringsSep "," pgExt}" in
              *pgvector*) : ;;
              *) echo "pgvector missing from the postgres package set"; exit 1 ;;
            esac
            touch $out
          '';

        # ---- O-4 local-LLM typed surface (KA-09.3, ko#112) ------------------
        #
        # redteam-ai-compat: the EXISTING freeform-path setting in
        # profiles/redteam-ai.nix (sets
        # kailash.layers.ops.categories.o-04.enable = true) must evaluate
        # WITH the typed option tree present - the typed entry absorbs the
        # profile's historical composition without a conflict (the §4.5
        # contract: same path, typed + freeform-born entries merge).
        # RED stub: fails while the typed spine is missing.
        o-04-options = pkgs.runCommand "o-04-options" { } ''
          test "${toString self.nixosConfigurations.kailash-redteam-ai.config.kailash.layers.ops.categories.o-04.enable}" = "1" \
            || { echo "o-04 enable did not resolve through the typed tree"; exit 1; }
          touch $out
        '';

        redteam-ai-compat = pkgs.runCommand "redteam-ai-compat" { } ''
          # The historical freeform entry (profiles/redteam-ai.nix) must
          # resolve through the TYPED tree - enable true, no conflict.
          test "${toString self.nixosConfigurations.kailash-redteam-ai.config.kailash.layers.ops.categories.o-04.enable}" = "1" \
            || { echo "redteam-ai o-04 setting did not survive the typed spine"; exit 1; }
          touch $out
        '';

        # ---- §4.5 OPS category modules (KA-08.1/08.2, ko#105/#106) ------
        #
        # Legs (eval-only, no new builds):
        #   * o-01-options / o-02-options — the §4.5 enable defaults are
        #     FALSE on the CORE substrate (opt-in-by-default verified at
        #     eval, not claimed) and the mlflow service enable defaults
        #     FALSE.
        #   * o-01-generated-drift — the committed generated package list
        #     equals the manifest-driven generator emit at THIS revision's
        #     pin: the generator runs against the vended kailash-packages
        #     manifest (through the flake input — never a hand-copy),
        #     output cmp'd against modules/ops/generated/o-01-*.nix. Drift
        #     (a manifest row edit, a pin bump) red-flags the PR until the
        #     list is regenerated in the same cycle.
        #   * o-01-enabled-toplevel — a synthetic lab host (NOT a product
        #     profile) with o-01 enabled evaluates to a toplevel —
        #     "enabling a test host installs without breaking eval".
        o-01-options = pkgs.runCommand
          "o-01-options" { } ''
          echo "--- o-01 category enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.ops.categories.o-01.enable}" = "false" \
            || { echo "o-01 categories.enable is not FALSE-default"; exit 1; }
          echo "--- mlflow service enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.services.kailash.mlflow.enable}" = "false" \
            || { echo "services.kailash.mlflow.enable is not FALSE-default"; exit 1; }
          echo "o-01-options: OK"
          touch $out
        '';

        o-01-generated-drift = pkgs.runCommand "o-01-generated-drift"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          python3 ${./tools/gen-category-packages.py} \
            --manifest-file ${kailash-packages.outPath + "/manifest/tools.yaml"} \
            --category o-01-mlops-ml-engineering > gen-o-01.nix
          GENERATED=${./modules/ops/generated/o-01-mlops-ml-engineering.nix}
          if ! cmp -s gen-o-01.nix "$GENERATED"; then
            echo "o-01 generated list DRIFTED from the generator emit:"
            diff -u "$GENERATED" gen-o-01.nix || true
            exit 1
          fi
          echo "o-01-generated-drift: OK (generator == committed)"
          touch $out
        '';

        #   * o-01-enabled-toplevel — REMOVED from checks by design: the
        #     synthetic hosts (kailash-o-01-enabled, kailash-mlflow-enabled)
        #     are nixosConfigurations only — `nix flake check` eval-checks
        #     every nixosConfiguration, so "enabling a test host installs
        #     without breaking eval" is proven by the eval gate itself;
        #     their closures never enter a CI build (no check attr).

        # Generator self-test: the core's asserted contracts (row
        # selection, module/bespoke exclusion, the §11.2 exp refuse,
        # determinism). RED stub: the empty emit fails the selection case.
        o-01-generator-self-test = pkgs.runCommand
          "o-01-generator-self-test"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          python3 ${./tools/gen-category-packages.py} --self-test
          touch $out
        '';

        # ---- §4.5 CLASSIC category surfaces (KA-06.1/06.2, ko#96/#97) ------
        #
        # The §4.5 contract for the four Wave-5 CLASSIC categories, mounted
        # by modules/classic/c-*.nix (the exemplar first). The exemplar
        # leg (ko#96):
        #   * run the committed generator (--self-test);
        #   * parity: the committed generated/manifest-ids.json must equal
        #     the generator's emit from the PINNED packages manifest
        #     (through the flake input — never a hand-copy);
        #   * eval the c-01 typed surface: `kailash.layers.classic.categories.c-01.packages`
        #     resolves as a config-only category module's default (RED
        #     stub: the module file consumes NOTHING yet — an empty
        #     default — so an enabled c-01 host installs nothing and the
        #     non-empty assertion is the watched red);
        #   * GREEN: the exemplar's install wiring consumes the generated
        #     artifact through its reviewed binding table and the same
        #     assertions pass through the SAME eval.
        c-01-exemplar = pkgs.runCommand "c-01-exemplar"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          # (1) the generator gates itself
          python3 ${./tools/gen-categories.py} \
            --manifest-file ${kailash-packages.outPath + "/manifest/tools.yaml"} \
            --self-test
          # (2) parity: committed artifact == generator emit from the
          # PINNED packages manifest
          GOT="$(python3 ${./tools/gen-categories.py} \
            --manifest-file ${kailash-packages.outPath + "/manifest/tools.yaml"})"
          echo "$GOT" > emit-real.json
          if python3 - emit-real.json ${./generated/manifest-ids.json} <<'PY' >delta.out 2>&1
import json, sys
got = json.load(open(sys.argv[1], encoding="utf-8"))
snap = json.load(open(sys.argv[2], encoding="utf-8"))
missing = []
extra = []
for cat, gdoc in sorted(got["categories"].items()):
    s = snap["categories"].get(cat)
    if s is None:
        extra.append(cat + ": category absent from the committed artifact")
        continue
    installable_g = sorted(gdoc["installable"])
    installable_s = sorted(s["installable"])
    gm = [i for i in installable_s if i not in installable_g]
    sx = [i for i in installable_g if i not in installable_s]
    if gm:
        missing.append(cat + ": " + ",".join(gm))
    if sx:
        extra.append(cat + ": " + ",".join(sx))
for cat in sorted(snap["categories"]):
    if cat not in got["categories"]:
        missing.append(cat + ": category absent from the generator emit")
if missing or extra:
    for m in missing:
        print("missing-from-emit: " + m)
    for e in extra:
        print("new-in-emit: " + e)
    sys.exit(1)
print("generator emit == committed manifest-ids artifact (all categories)")
PY
          then cat delta.out
          else
            echo "c-01-exemplar: manifest-ids drift from the pinned manifest (regenerate with \`make gen-categories\`):"
            cat delta.out
            exit 1
          fi
          # (3) the four Wave-5 CLASSIC counts print for the record
          python3 -c "import json; d = json.load(open('emit-real.json')); c = d['categories']; print('installable counts: c-01=' + str(len(c['c-01-information-gathering']['installable'])) + ' c-02=' + str(len(c['c-02-vulnerability-analysis']['installable'])) + ' c-04=' + str(len(c['c-04-database-assessment']['installable'])) + ' c-06=' + str(len(c['c-06-reverse-engineering']['installable'])) + ' (manifest total ' + str(d['tools_total']) + ' tools)')"
          # (4) the §4.5 exemplar host: an enabled c-01 category on the
          # CORE floor must resolve a NON-EMPTY install set (RED stub:
          # the module consumes nothing yet -> empty -> the watched red).
          PKGS="${toString self.nixosConfigurations.kailash-c-01-exemplar.config.kailash.layers.classic.categories.c-01.packages}"
          echo "c-01 install set: ${lib.concatStringsSep " " (map (p: p.pname or p.name) self.nixosConfigurations.kailash-c-01-exemplar.config.kailash.layers.classic.categories.c-01.packages)}"
          test -n "$PKGS" || { echo "c-01-exemplar: the enabled c-01 category installs NOTHING (the exemplar's install wiring is missing)"; exit 1; }
          echo "c-01-exemplar: OK"
          touch $out
        '';

        # ---- The four CLASSIC modules together (KA-06.2, ko#97) -----------
        #
        # The full-profile composition gate: with NOTHING enabled the
        # kailash-full floor installs zero category tools; with all four
        # shipped categories ON the composed systemPackages carries the
        # flagship tool of each (nmap/sqlmap/nikto/ghidra) AND the
        # categories' sets stay manifest-verified (the c-01-exemplar
        # leg owns the c-01 parity). RED note (KA-06.2): landed with the
        # modules in the same GREEN cycle — the watched red for the
        # SECOND-FOUR was the same-shape one-off: before this commit the
        # c-04/c-02/c-06 ids were unresolvable on any host (the tree had
        # no such modules), so this check's eval itself failed.
        classic-four-eval = pkgs.runCommand "classic-four-eval"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          FULL="${self.nixosConfigurations.kailash-full.config.system.build.toplevel}"
          test -n "$FULL" && echo "kailash-full toplevel: $FULL"
          # Nothing enabled on the CORE floor: the minimal host's PATH
          # must NOT carry the categories' flagships.
          MIN_NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-minimal.config.environment.systemPackages)}"
          for tool in nmap sqlmap nikto ghidra; do
            case " $MIN_NAMES " in
              *" $tool "*) { echo "kailash-minimal must NOT carry $tool (opt-in by default)"; exit 1; } ;;
            esac
          done
          # All four shipped categories ON: the composed PATH carries the
          # flagship of each + a per-category probe tool.
          FULL_NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-full.config.environment.systemPackages)}"
          for tool in nmap sqlmap nikto ghidra radare2 gdb binwalk; do
            case " $FULL_NAMES " in
              *" $tool "*) ;;
              *) { echo "kailash-full PATH missing $tool (the four shipped CLASSIC categories must compose)"; exit 1; } ;;
            esac
          done
          # Per-category install sets resolve: c-04 = 6 (mssql-cli is a
          # manifest-bespoke row whose overlay row has not landed — the
          # named drop), c-02 = 5 (legion same; gvm = the module-status
          # deferred GVM row, ko#97), c-06 = 16 (26 manifest ids:
          # pwndbg, peda, javasnoop, jd-gui, smali, unipacker,
          # pyinstaller-extractor drop as overlay-pending, angr drops on
          # its build failure ("requires setuptools-rust", hosted job
          # 114623996385), qiling is marked broken, cstool+capstone
          # dedupe to one capstone derivation).
          C04="${toString (builtins.length self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-04.packages)}"
          C02="${toString (builtins.length self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-02.packages)}"
          C06="${toString (builtins.length self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-06.packages)}"
          echo "install-set counts: c-04=$C04 c-02=$C02 c-06=$C06"
          test "$C04" = "6" || { echo "c-04 install set: expected 6, got $C04"; exit 1; }
          test "$C02" = "5" || { echo "c-02 install set: expected 5 (gvm module-deferred, legion overlay-pending), got $C02"; exit 1; }
          test "$C06" = "16" || { echo "c-06 install set: expected 16 (overlay-pending + angr-build-gap + qiling-broken + cstool dedupe), got $C06"; exit 1; }
          echo "classic-four-eval: OK"
          touch $out
        '';

        # ---- O-2 legs (KA-08.2) — same shape as the O-1 legs ----
        o-02-options = pkgs.runCommand
          "o-02-options" { } ''
          echo "--- o-02 category enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.ops.categories.o-02.enable}" = "false" \
            || { echo "o-02 categories.enable is not FALSE-default"; exit 1; }
          echo "o-02-options: OK"
          touch $out
        '';

        o-02-generated-drift = pkgs.runCommand "o-02-generated-drift"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          python3 ${./tools/gen-category-packages.py} \
            --manifest-file ${kailash-packages.outPath + "/manifest/tools.yaml"} \
            --category o-02-compute-serving-infrastructure > gen-o-02.nix
          GENERATED=${./modules/ops/generated/o-02-compute-serving-infrastructure.nix}
          if ! cmp -s gen-o-02.nix "$GENERATED"; then
            echo "o-02 generated list DRIFTED from the generator emit:"
            diff -u "$GENERATED" gen-o-02.nix || true
            exit 1
          fi
          echo "o-02-generated-drift: OK (generator == committed)"
          touch $out
        '';
      };


      # ---- Audit hostile fixture (KA-18.2, os#93) --------------------------
      #
      # A synthetic host that VIOLATES the no-auto-start contract on
      # purpose: an exp-class tool wanted via a systemd service with the
      # lab shell key pre-set. NOT a product profile; consumed only by the
      # audit-hostile-fixture check (the negative case proven in CI).
      nixosConfigurations.kailash-audit-hostile = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-audit-hostile";
            kailash.audit.autoStart.expToolNames = [ "exp-tool-by-audit-fixture" ];
            systemd.services.kailash-audit-hostile-fixture = {
              description = "Synthetic exp auto-start violator (audit fixture)";
              wantedBy = [ "multi-user.target" ];
              serviceConfig.ExecStart =
                "!/bin/sh -c 'KAILASH_LAB_MODE=1 exec exp-tool-by-audit-fixture'";
            };
          }
        ];
      };

      # The §4.5 EXEMPLAR host (KA-06.1, ko#96): the CORE floor with C-1
      # Information Gathering enabled. RED stub: the c-01 module
      # consumes nothing yet (the manifest-generated install set is not
      # wired), so the host carries an EMPTY c-01 install set and the
      # c-01-exemplar check's non-empty assertion is the watched red.
      nixosConfigurations.kailash-c-01-exemplar = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          { kailash.layers.classic.categories.c-01.enable = true; }
        ];
      };

      # The FULL profile host (KA-06.2, ko#97): the CORE floor + the four
      # shipped CLASSIC categories (c-01, c-02, c-04, c-06) — the §4.5
      # composition profile. Eval-gated (the classic-four-eval check
      # asserts the categories' install sets resolve and the flagship
      # tools reach the composed PATH); remaining categories join the
      # profile as their modules land.
      nixosConfigurations.kailash-full = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [ ./profiles/full.nix ];
      };

      # Layer-ATTACK red-team profile (KA-17.1, os#114): CORE floor + Layer
      # ATTACK full + O-4 (local inference labs). Evaluates through the
      # module tree with the flat option spine until the Wave-5
      # per-category wiring lands (see the profile header note).
      nixosConfigurations.kailash-redteam-ai = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [ ./profiles/redteam-ai.nix ];
      };

      # Hardened minimal profile (KA-17.2, os#115): the CORE substrate
      # floor with the hardening posture pinned — labMode OFF explicitly;
      # the §8.3 hardening module (sysctl, firewall default-deny,
      # wheel-only sudo) rides the base fold. Zero categories, like
      # minimal — the named, reviewable not-a-lab-host posture.
      nixosConfigurations.kailash-minimal-hardened = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [ ./profiles/minimal-hardened.nix ];
      };

      # §4.5 category-install fixture (KA-08.1, ko#105): a synthetic host
      # with the O-1 category ENABLED — proves "enabling a test host
      # installs without breaking eval". NOT a product profile; the
      # fixture pattern the safety legs use.
      nixosConfigurations.kailash-o-01-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-o-01-enabled";
            kailash.layers.ops.categories.o-01.enable = true;
          }
        ];
      };

      # The mlflow SERVICE composed (KA-08.1): a synthetic host with
      # services.kailash.mlflow ENABLED (loopback default port 5000) —
      # EVAL-ONLY (no check leg, no CI build): nix flake check evaluates
      # every nixosConfiguration, so this host proves the service module
      # composes and produces the unit without building its closure; the
      # unit + port assertions ride flake-eval and the PR's verbatim
      # `nix eval` lines. NOT a product profile.
      nixosConfigurations.kailash-mlflow-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-mlflow-enabled";
            services.kailash.mlflow.enable = true;
          }
        ];
      };

      # devShells per category with KA-09; images with the images wave;
      # remaining hosts (kailash-full etc.) land with their profile items.
    };
}
