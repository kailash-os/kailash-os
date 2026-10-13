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
          # KA-08.3's O-5 SDK surface resolves python3Packages.tensorflow
          # (2.21.0 at the current pin — marked broken on linux/darwin by
          # the tensorflow-bin packaging at nixpkgs e7439b6b). The row is
          # the manifest's ROUTED row (the binding table, probed); the
          # handler keeps the derivation RESOLVABLE for the install set /
          # devShell compositions until the upstream packaging heals,
          # without widening anything else.
          problems.handlers = {
            tensorflow.broken = "warn";
          };
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

        # o-03-generated-drift (KA-09.1): the committed o-03 generated
        # package list == the generator emit from the PINNED packages
        # manifest through the flake input (never a hand-copy) — the o-02
        # leg's exact shape. RED stub: the generated list is ABSENT at
        # this commit (modules/ops/generated/o-03-vector-stores-
        # retrieval.nix) — the leg's flake-input eval of the module tree
        # throws (file not found) and this leg fails: the watched red.
        # GREEN: the generator-emit file lands and `cmp` proves byte
        # identity at every later revision.
        o-03-generated-drift = pkgs.runCommand "o-03-generated-drift"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          python3 ${./tools/gen-category-packages.py} \
            --manifest-file ${kailash-packages.outPath + "/manifest/tools.yaml"} \
            --category o-03-vector-stores-retrieval > gen-o-03.nix
          GENERATED=${./modules/ops/generated/o-03-vector-stores-retrieval.nix}
          if ! cmp -s gen-o-03.nix "$GENERATED"; then
            echo "o-03 generated list DRIFTED from the generator emit:"
            diff -u "$GENERATED" gen-o-03.nix || true
            exit 1
          fi
          echo "o-03-generated-drift: OK (generator == committed)"
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

        # O-4 services leg (KA-09.3, ko#112). RED stub → GREEN: with the
        # typed tree present but NO o-04 category module on the fold, an
        # o-04-ON host (kailash-redteam-ai — the profile opts in via the
        # §4.5 category switch) kept services.ollama at its upstream
        # FALSE default — that was the watched RED. GREEN (the o-04
        # module on the ops fold): the service wiring asserts through the
        # SAME eval — ollama ON (the category switch is the opt-in), webui
        # ON (default-with-category sibling toggle), loopback binds on
        # both (the §11.2 posture recorded at the module), the webui
        # environment pointed at the loopback Ollama API (the ko#112
        # pairing), loadModels EMPTY (the module never auto-pulls — the
        # tiny test model is an operator step, documented in the module
        # header), and the off-host posture: an o-04-OFF host (CORE
        # substrate) keeps BOTH services FALSE (opt-in by default).
        o-04-services = pkgs.runCommand "o-04-services" { } ''
          test "${toString self.nixosConfigurations.kailash-redteam-ai.config.services.ollama.enable}" = "1" \
            || { echo "o-04 module missing: services.ollama.enable stays FALSE on an enabled o-04 host (KA-09.3 watched RED - modules/ops/o-04-local-llm-inference-labs.nix lands in the GREEN cycle, ko#112)"; exit 1; }
          test "${toString self.nixosConfigurations.kailash-redteam-ai.config.services.open-webui.enable}" = "1" \
            || { echo "webui toggle did not wire services.open-webui on the o-04 host"; exit 1; }
          test "${self.nixosConfigurations.kailash-redteam-ai.config.services.ollama.host}" = "127.0.0.1" \
            || { echo "ollama host is not the loopback default"; exit 1; }
          test "${self.nixosConfigurations.kailash-redteam-ai.config.services.open-webui.host}" = "127.0.0.1" \
            || { echo "open-webui host is not the loopback default"; exit 1; }
          test "${self.nixosConfigurations.kailash-redteam-ai.config.services.open-webui.environment.OLLAMA_API_BASE_URL}" = "http://127.0.0.1:11434" \
            || { echo "open-webui is not pointed at the loopback ollama API"; exit 1; }
          test "${toString (builtins.length self.nixosConfigurations.kailash-redteam-ai.config.services.ollama.loadModels)}" = "0" \
            || { echo "the o-04 module must NEVER auto-pull models (loadModels stays empty - the tiny model is an operator step)"; exit 1; }
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.services.ollama.enable}" = "false" \
            || { echo "o-04-OFF host must keep services.ollama off (opt-in by default)"; exit 1; }
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.services.open-webui.enable}" = "false" \
            || { echo "o-04-OFF host must keep services.open-webui off (opt-in by default)"; exit 1; }
          echo "o-04-services: ollama+open-webui wired on the o-04-ON host (loopback, webui->loopback ollama, no auto-pull), both off on the CORE substrate"
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

        # ---- VM smoke contract (KA-06.3, ko#98) ----------------------------
        #
        # The eval-side watchdog binding the booted suite (vmTests,
        # tests/c-01.nix etc.) to the §4.5 module options:
        #   * per category: the vmTests tables' PATH rows must equal the
        #     module option's install set compiled through the shared
        #     ledger (tests/vm-smoke-tables.nix pathNameForPname — the
        #     probed-at-pin manifest id → derivation-name map;
        #     binAliases + helpExceptions documented rows ride the same
        #     ledger);
        #   * non-empty per category + flagship presence by NAME at the
        #     option level (nmap, sqlmap, nikto, ghidra — ko#98's
        #     anchors; boot legs assert the VM PATH form).
        #   * full-profile boot host eval (kailash-vm-full, the vmTests
        #     suite's boot target) resolves non-empty and carries the
        #     nmap row.
        # Watched RED (the bootstrap): with the bootstrap STUB (the
        # tables file emitting empty sets) the (2) diffs failed loudly —
        # every category printed `tables != eval-side` with both sides —
        # and the kailash-vm-full host did not exist yet (the (1) eval
        # failed). The RED commit message carries that output verbatim.
        # VM reality (ko#98): hosted CI cannot BOOT (no KVM) and the
        # lane box cannot build x86_64-linux — this leg is the
        # always-run proof; the boots run on a Linux VM host per
        # tests/README.md (PENDING-VM posture recorded on the issue).
        classic-vm-smoke-contract =
          let
            tables = import ./tests/vm-smoke-tables.nix { inherit lib; };

            # One SIDE per category, as a sorted, joined PATH-name row
            # string (diff-friendly; Nix attr iteration is name-sorted).
            # Eval side: the §4.5 module option's install set compiled
            # through pathNameForPname (probed-at-pin id map; a pname
            # whose binding moved REDs here — the exact watched drift).
            evalSide = cat:
              lib.sort (a: b: a < b) (lib.unique (lib.concatMap
                (p:
                  let
                    n = p.pname or (builtins.parseDrvName p.name).name;
                  in
                    tables.pathNameForPname.${n} or [ n ])
                self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.${cat}.packages));
            tablesSide = cat: lib.sort (a: b: a < b) tables.pathNames.${cat};
            joined = rows: lib.concatStringsSep "," rows;
          in
          pkgs.runCommand "classic-vm-smoke-contract"
            {
              nativeBuildInputs = [ pkgs.bash ];
            } ''
            # (1) the profile host AND the boot-suite host (kailash-vm-full,
            # the vmTests legs' boot target — every one of its nodes
            # imports the same profiles/full.nix) evaluate with all four
            # categories enabled
            ${lib.concatStringsSep "\n" (map (host: ''
            ${lib.concatStringsSep "\n" (map (cat: ''
            test "${toString self.nixosConfigurations.${host}.config.kailash.layers.classic.categories.${cat}.enable}" = "1" \
              || { echo "${host}: ${cat} not enabled (the boot suite's host drifted from profiles/full.nix)"; exit 1; }
          '') [ "c-01" "c-02" "c-04" "c-06" ])}
          '') [ "kailash-full" "kailash-vm-full" ])}

            # (2) the vmTests PATH tables == the module options (through
            # the shared ledger; both sides baked at eval — the same
            # tables the boot legs consume)
            ${lib.concatStringsSep "\n" (map (cat: ''
            if test "${joined (evalSide cat)}" = "${joined (tablesSide cat)}"; then
              echo "${cat}: tables == eval-side (${toString (lib.length (tablesSide cat))} rows)"
            else
              echo "${cat}: vm-smoke tables != eval-side (binding-table or ledger drift):"
              echo "  eval-side: ${joined (evalSide cat)}"
              echo "  tables   : ${joined (tablesSide cat)}"
              exit 1
            fi
          '') [ "c-01" "c-02" "c-04" "c-06" ])}

            # (3) flagships resolve BY NAME at the option level (nmap,
            # sqlmap, nikto, ghidra — ko#98's anchors; the boot legs
            # assert the VM PATH form).
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (cat: flags: ''
            CAT_NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.${cat}.packages)}"
            ${lib.concatStringsSep "\n" (map (flag: ''
            case " $CAT_NAMES " in *" ${flag} "*) ;; *) echo "${cat}: flagship ${flag} missing from the option set"; exit 1;; esac
          '') flags)}
          '') tables.flagshipCmds)}

            echo "classic-vm-smoke-contract: OK (tables == module options, boot host = full profile, flagships resolve)"
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

        # ---- §3.2 C-2 GVM/OpenVAS service module (KA-27, ko#27) -------------
        #
        # The module-status manifest row's deliverable: the service module
        # ships the manager/redis/feed surface the c-02 category module
        # excludes. Legs (derivation-level inputs ONLY — no closure walks
        # on the 7GB arm64 runners):
        #   * gvm-options — the opt-in posture plus the §3.2 surface:
        #     enable defaults FALSE on the CORE substrate and NOTHING
        #     references the service surface on the gvm-OFF host (no gvmd
        #     unit, no dedicated redis server, no feed units — the
        #     no-auto-start audit, eval-time); an ENABLED host must compose
        #     the dedicated redis server (services.redis.servers
        #     .kailash-gvm — loopback bind, TCP off, unix socket under
        #     /run/redis-kailash-gvm) and the feed-sync service + timer
        #     units. RED stub: the module is enable-only, so every gvm-ON
        #     assertion fails (the `or` guards keep the leg's eval alive —
        #     the RED fires in the script's own output).
        #   * gvm-manager-package — the module's package CONTRACT: gvmd is
        #     ABSENT from the pinned nixpkgs (8c3cede — probed at RED
        #     prep; only greenbone-feed-sync + gvm-tools exist there), so
        #     an enabled host with NO manager package must THROW at eval
        #     (the require — proven with builtins.tryEval, never by
        #     building), and an operator-supplied `package` must compose.
        gvm-options = pkgs.runCommand "gvm-options"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          echo "--- gvm: enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.services.kailash.gvm.enable}" = "false" \
            || { echo "services.kailash.gvm.enable is not FALSE-default"; exit 1; }
          echo "--- gvm-OFF: no gvmd unit, no dedicated redis server, no feed units on the minimal host"
          test "${lib.boolToString (self.nixosConfigurations.kailash-minimal.config.systemd.units ? "kailash-gvmd.service")}" = "false" \
            || { echo "kailash-gvmd.service must NOT exist on the gvm-OFF host"; exit 1; }
          test "${lib.boolToString (self.nixosConfigurations.kailash-minimal.config.services.redis.servers ? "kailash-gvm")}" = "false" \
            || { echo "services.redis.servers.kailash-gvm must NOT exist on the gvm-OFF host"; exit 1; }
          test "${lib.boolToString (self.nixosConfigurations.kailash-minimal.config.systemd.units ? "kailash-gvm-feed.service")}" = "false" \
            || { echo "kailash-gvm-feed.service must NOT exist on the gvm-OFF host"; exit 1; }
          test "${lib.boolToString (self.nixosConfigurations.kailash-minimal.config.systemd.units ? "kailash-gvm-feed.timer")}" = "false" \
            || { echo "kailash-gvm-feed.timer must NOT exist on the gvm-OFF host"; exit 1; }
          echo "--- gvm-ON (kailash-gvm-enabled): the dedicated §3.2 redis server composes"
          test "${toString (self.nixosConfigurations.kailash-gvm-enabled.config.services.redis.servers.kailash-gvm.enable or false)}" = "1" \
            || { echo "the gvm-ON host must compose services.redis.servers.kailash-gvm (enable=true)"; exit 1; }
          test "${lib.boolToString (self.nixosConfigurations.kailash-gvm-enabled.config.systemd.units ? "redis-kailash-gvm.service")}" = "true" \
            || { echo "redis-kailash-gvm.service must compose on the gvm-ON host"; exit 1; }
          SOCK="${toString (self.nixosConfigurations.kailash-gvm-enabled.config.services.redis.servers.kailash-gvm.unixSocket or "")}"
          case "$SOCK" in
            /run/redis-kailash-gvm/*) echo "dedicated redis unix socket: $SOCK" ;;
            *) echo "kailash-gvm redis server must be unix-socket-only under /run/redis-kailash-gvm (got: '$SOCK')"; exit 1 ;;
          esac
          BIND="${toString (self.nixosConfigurations.kailash-gvm-enabled.config.services.redis.servers.kailash-gvm.bind or "")}"
          test "$BIND" = "127.0.0.1" || { echo "kailash-gvm redis server must bind the loopback (got: '$BIND')"; exit 1; }
          PORT="${toString (self.nixosConfigurations.kailash-gvm-enabled.config.services.redis.servers.kailash-gvm.port or "unset")}"
          test "$PORT" = "0" || { echo "kailash-gvm redis server must NOT listen on TCP (port must be 0, got: '$PORT')"; exit 1; }
          echo "--- gvm-ON: the feed-sync units compose"
          test "${lib.boolToString (self.nixosConfigurations.kailash-gvm-enabled.config.systemd.units ? "kailash-gvm-feed.service")}" = "true" \
            || { echo "kailash-gvm-feed.service must exist on the gvm-ON host"; exit 1; }
          test "${lib.boolToString (self.nixosConfigurations.kailash-gvm-enabled.config.systemd.units ? "kailash-gvm-feed.timer")}" = "true" \
            || { echo "kailash-gvm-feed.timer must exist on the gvm-ON host"; exit 1; }
          echo "gvm-options: OK"
          touch $out
        '';

        gvm-manager-package = pkgs.runCommand "gvm-manager-package" { } ''
          echo "--- gvm-manager-package: the manager-derivation require/throw posture"
          test "${lib.boolToString (self.nixosConfigurations.kailash-gvm-enabled.config.services.kailash.gvm ? "package")}" = "true" \
            || { echo "services.kailash.gvm must declare the package contract option (the manager-derivation require)"; exit 1; }
          NO_PKG_THROW="${lib.boolToString (let t = builtins.tryEval (self.nixosConfigurations.kailash-minimal.extendModules {
            modules = [ { services.kailash.gvm.enable = true; } ];
          }).config.systemd.units; in t.success && t.value ? "kailash-gvmd.service" && (builtins.tryEval t.value."kailash-gvmd.service".text).success)}"
          test "$NO_PKG_THROW" = "false" \
            || { echo "the manager require must THROW at eval when enable=true and no manager package is set (gvmd is absent from the pin)"; exit 1; }
          WITH_PKG_COMPOSES="${lib.boolToString (let t = builtins.tryEval (self.nixosConfigurations.kailash-minimal.extendModules {
            modules = [ {
              services.kailash.gvm.enable = true;
              services.kailash.gvm.package = pkgs.stdenv.mkDerivation {
                name = "gvm-manager-standin";
                unpackPhase = "true";
                installPhase = "mkdir -p $out/bin; printf '#!/bin/sh\necho gvmd-standin\n' > $out/bin/gvmd; chmod +x $out/bin/gvmd";
              };
            } ];
          }).config.systemd.units; in t.success && (t.value ? "kailash-gvmd.service"))}"
          test "$WITH_PKG_COMPOSES" = "true" \
            || { echo "an operator-supplied manager package must compose the gvmd unit (no throw)"; exit 1; }
          echo "gvm-manager-package: OK"
          touch $out
        '';

        # ---- C-3 Web Application Assessment (KA-07.1, ko#99) ----------------
        #
        # The §4.5 category module for the tenth CLASSIC manifest category,
        # mounted by modules/classic/c-03-web-application-assessment.nix on
        # the same spine the exemplar defined. The leg:
        #   * asserts the spine's §4.5 posture on THIS category: c-03
        #     enable defaults FALSE on the CORE substrate (nothing on PATH
        #     until the category switch is on — opt-in by default);
        #   * the composition host (kailash-c-03-composition: the CORE
        #     floor with c-03 enabled) must resolve a NON-EMPTY install
        #     set AND carry the flagship — OWASP ZAP — on the composed
        #     PATH (RED stub: the module consumes NOTHING yet — an empty
        #     config — so the host installs nothing and both assertions
        #     are the watched red);
        #   * GREEN: the module's reviewed binding table resolves the
        #     generated id list (generated/manifest-ids.json,
        #     c-03-web-application-assessment — the c-01-exemplar leg owns
        #     the artifact parity for ALL categories) and the SAME
        #     assertions pass through the SAME eval.
        #
        # Watched RED (KA-07.1): with the stub module imported the host
        # evaluates but installs NOTHING —
        #   `c-03-options: the enabled c-03 category installs NOTHING`
        #   / `c-03-options: the composed PATH is missing the flagship zap`
        # — while every pre-existing leg stays green.
        c-03-options = pkgs.runCommand "c-03-options" { } ''
          echo "--- c-03 category enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.classic.categories.c-03.enable}" = "false" \
            || { echo "c-03 categories.enable is not FALSE-default"; exit 1; }
          PKGS="${toString self.nixosConfigurations.kailash-c-03-composition.config.kailash.layers.classic.categories.c-03.packages}"
          echo "c-03 install set: ${lib.concatStringsSep " " (map (p: p.pname or p.name) self.nixosConfigurations.kailash-c-03-composition.config.kailash.layers.classic.categories.c-03.packages)}"
          test -n "$PKGS" || { echo "c-03-options: the enabled c-03 category installs NOTHING (the module's install wiring is missing)"; exit 1; }
          NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-c-03-composition.config.environment.systemPackages)}"
          for tool in zap burpsuite caido-desktop graphw00f; do
            case " $NAMES " in
              *" $tool "*) ;;
              *) { echo "c-03-options: the composed PATH is missing the flagship $tool (the C-3 web assessment surface must compose)"; exit 1; } ;;
            esac
          done
          echo "c-03-options: OK"
          touch $out
        '';

        # ---- C-5 offline-credential + C-7 opt-in posture (KA-07.2, ko#100) -
        #
        # GREEN (this commit): the c-05 module's manifest-generated
        # binding table fills the mount
        # (modules/classic/c-05-password-offline-credential.nix) and the
        # SAME assertions (non-empty set, hashcat present) pass through
        # the SAME eval (host composition). The watched-red history: the
        # RED stub commit landed the module consuming NOTHING — an
        # enabled c-05 composition resolved an EMPTY install set and
        # this leg failed on the non-empty assertion (the same shape as
        # the c-01-exemplar red, ko#96); this commit flipped the verdict
        # through one and the same eval.
        #
        # Wordlists posture (asserted as data below once the pack lane
        # lands): seclists is a manifest status:data row — the generator
        # excludes it from categories.c-05.installable, so the category
        # module can never install it; the wordlists pack rides the
        # opt-in kailash-data.wordlists-mega derivation in
        # kailash-packages (ko#100), never a category-module row.
        c-05-options =
          let
            c05Host = (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [ { kailash.layers.classic.categories.c-05.enable = true; } ];
            });
          in
          pkgs.runCommand
            "c-05-options" { } ''
            echo "--- c-05: the enabled composition installs the offline-credential set"
            C05="${toString (builtins.length
              c05Host.config.kailash.layers.classic.categories.c-05.packages)}"
            echo "c-05 install-set count: $C05"
            test "$C05" -gt 0 \
              || { echo "c-05-options: the enabled c-05 category installs NOTHING (the module's install wiring is missing)"; exit 1; }
            NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) c05Host.config.kailash.layers.classic.categories.c-05.packages)}"
            echo "c-05 install set: $NAMES"
            case " $NAMES " in
              *" hashcat "*) : ;;
              *) echo "c-05 install set missing hashcat (the hash-cracking flagship)"; exit 1 ;;
            esac
            echo "c-05-options: OK"
            touch $out
          '';

        # C-7 posture leg (GREEN from RED by design — it pins the
        # posture, it does not watch a fix): C-7 ships as the
        # kailash-data.sdr-tools opt-in data pack (ko#100), the stub
        # module declares nothing, and enable stays default-false on
        # every host — C-7 absent from minimal/standard/full (the ko#100
        # acceptance; "standard" is the CORE substrate here: the
        # minimal floor is the standard profile and full builds on it).
        # A later edit that flips c-07.enable on any CORE-derived
        # profile turns this leg red.
        c-07-optin-posture = pkgs.runCommand
          "c-07-optin-posture" { } ''
          echo "--- c-07: the opt-in data-pack posture (off everywhere by default)"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.classic.categories.c-07.enable}" = "false" \
            || { echo "c-07 must stay OFF on the CORE substrate (kailash-minimal) — the sdr-tools pack is opt-in"; exit 1; }
          test "${lib.boolToString self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-07.enable}" = "false" \
            || { echo "c-07 must stay OFF on the full profile — C-7 is absent from minimal/standard/full (ko#100 acceptance)"; exit 1; }
          MIN_C07="${toString (builtins.length self.nixosConfigurations.kailash-minimal.config.kailash.layers.classic.categories.c-07.packages)}"
          FULL_C07="${toString (builtins.length self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-07.packages)}"
          test "$MIN_C07" = "0" \
            || { echo "c-07 packages is NON-EMPTY on kailash-minimal ($MIN_C07) — the stub must mount nothing"; exit 1; }
          test "$FULL_C07" = "0" \
            || { echo "c-07 packages is NON-EMPTY on kailash-full ($FULL_C07) — the stub must mount nothing"; exit 1; }
          echo "c-07-optin-posture: OK (enable false on minimal+full, empty mounts)"
          touch $out
        '';

        # ---- C-10 Runtime AppSec for AI (KA-07.4, ko#102) -----------------
        #
        # Same-shape leg off the O-1 options pattern: (1) the c-10 switch
        # defaults FALSE on the CORE substrate (opt-in posture, the §4.5
        # floor's nothing-enabled invariant); (2) the composition host —
        # c-10 ENABLED on kailash-minimal — resolves a NON-EMPTY install
        # set with the PRIMARY flagship mitmproxy present.
        #
        # Watched RED (KA-07.4): at the stub commit the c-10 module
        # consumes NOTHING (an empty packages default), so assertion (2)
        # fails while (1) stays green. GREEN: the module's reviewed
        # binding table consumes the generated id list and both halves
        # pass through the SAME eval path.
        #
        # The manifest surface (5 installable + 2 excluded data rows at
        # this pin) is owned by the c-01-exemplar parity leg (generator
        # emit vs the committed artifact, all categories) — this leg
        # asserts the c-10 resolution only.
        c-10-options = pkgs.runCommand
          "c-10-options" { } ''
          echo "--- c-10 category enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.classic.categories.c-10.enable}" = "false" \
            || { echo "c-10 categories.enable is not FALSE-default"; exit 1; }
          echo "--- c-10 enabled composition resolves a non-empty install set"
          C10="${toString self.nixosConfigurations.kailash-c-10-enabled.config.kailash.layers.classic.categories.c-10.packages}"
          echo "c-10 install set: ${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-c-10-enabled.config.kailash.layers.classic.categories.c-10.packages)}"
          test -n "$C10" || { echo "c-10-options: the enabled c-10 category installs NOTHING (the module's install wiring is missing - the watched red)"; exit 1; }
          echo "--- c-10 primary flagship mitmproxy present in the composed set"
          C10NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-c-10-enabled.config.kailash.layers.classic.categories.c-10.packages)}"
          case " $C10NAMES " in
            *" mitmproxy "*) ;;
            *) { echo "c-10-options: mitmproxy (the c-10 PRIMARY flagship) missing from the install set; got: $C10NAMES"; exit 1; } ;;
          esac
          echo "c-10-options: OK"
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

        # ---- C-8 + C-9 typed surfaces (KA-07.3, ko#101) --------------------
        #
        # Same-shape §4.5 legs off the four-CLASSIC gates:
        #   * c-08-options — enabled composition NON-EMPTY (RED stub: the
        #     module mounts nothing → "installs NOTHING"), metasploit
        #     PRESENT once the binding table binds (pkgs.metasploit
        #     carries the whole msf* bin family) and the arsenal rows
        #     (impacket, mimikatz, crackmapexec, covenant, empire,
        #     bloodhound) ABSENT — the software-only exclusion holds at
        #     every eval, not just in prose;
        #   * c-09-options — enabled composition NON-EMPTY (RED stub
        #     same shape) and the service-module rows (timesketch,
        #     faraday, pwndoc-ng) ABSENT from the install set BY
        #     CONSTRUCTION — they ship as service modules in a later
        #     lane, never as package-list rows.
        c-08-options =
          let
            c8Host = (self.nixosConfigurations.kailash-c-08-enabled.config
              .kailash.layers.classic.categories.c-08);
            c8Names = map (p: p.pname or (builtins.parseDrvName p.name).name) c8Host.packages;
          in
          pkgs.runCommand "c-08-options" { } ''
            install_set="${toString c8Names}"
            echo "c-08 install set: $install_set"
            test -n "$install_set" \
              || { echo "c-08-options: the enabled c-08 category installs NOTHING (the binding table is missing)"; exit 1; }
            for expected in metasploit-framework weevely laudanum pspy unix-privesc-check; do
              case " $install_set " in
                *" $expected "*) : ;;
                *) echo "c-08 install set missing $expected"; exit 1 ;;
              esac
            done
            # Software-only exclusion (§3.7/§4.5): the arsenal rows never
            # reach the install set — the manifest ledger never had them
            # and the binding table cannot invent them.
            for banned in impacket mimikatz crackmapexec covenant empire bloodhound; do
              case " $install_set " in
                *" $banned "*) { echo "c-08 arsenal exclusion VIOLATED: $banned in the install set"; exit 1; } ;;
              esac
            done
            echo "c-08-options: OK (software-only posture verified at eval)"
            touch $out
          '';

        c-09-options =
          let
            c9Host = (self.nixosConfigurations.kailash-c-09-enabled.config
              .kailash.layers.classic.categories.c-09);
            c9Names = map (p: p.pname or (builtins.parseDrvName p.name).name) c9Host.packages;
          in
          pkgs.runCommand "c-09-options" { } ''
            install_set="${toString c9Names}"
            echo "c-09 install set: $install_set"
            test -n "$install_set" \
              || { echo "c-09-options: the enabled c-09 category installs NOTHING (the binding table is missing)"; exit 1; }
            for expected in autopsy sleuthkit volatility3 testdisk regripper chainsaw hayabusa dc3dd; do
              case " $install_set " in
                *" $expected "*) : ;;
                *) echo "c-09 install set missing $expected"; exit 1 ;;
              esac
            done
            # Service-module rows are ABSENT BY CONSTRUCTION: they ship
            # as systemd service modules (later lane), never as
            # package-list rows.
            for service_row in timesketch faraday pwndoc-ng; do
              case " $install_set " in
                *" $service_row "*) { echo "c-09 service-module row $service_row must NOT be in the install set"; exit 1; } ;;
              esac
            done
            echo "c-09-options: OK (service-module rows excluded by construction)"
            touch $out
          '';

        # ---- O-3 docker-wrapper stores (KA-09.2, ko#111, §5.4 Shape 3) -----
        #
        # Each declared backend id stands up ONE oci-containers container
        # (podman substrate), image pinned in the module, autoStart false
        # (the operator starts heavy stores; no-auto-start posture §11.2).
        # The posture is DOCUMENTED per store (the acceptance clause):
        # docs/guide/o-03-docker-wrapper-stores.md carries image, port and
        # wrapper-class lines per id, and the check cross-asserts the
        # module's rendered container attrs against the documented posture.
        # RED stub (KA-09.2): the posture doc is absent - the check fails
        # until the GREEN commit lands the wrappers' per-store posture.
        o-03-backends-doc = pkgs.runCommand "o-03-backends-doc" { }
          ''
          f=${./docs/guide/o-03-docker-wrapper-stores.md}
          test -f "$f" || { echo "the docker-wrapper posture doc is missing"; exit 1; }
          grep -q "weaviate" "$f"
          grep -q "milvus" "$f"
          grep -q "elasticsearch" "$f"
          touch $out
        '';

        o-03-backends-containers =
          let
            o3Host = (self.nixosConfigurations.kailash-redteam-ai.extendModules {
              modules = [
                {
                  kailash.layers.ops.categories.o-03.enable = true;
                  kailash.layers.ops.categories.o-03.backends = [
                    "weaviate"
                    "milvus"
                    "elasticsearch"
                  ];
                }
              ];
            });
            ctrNames = builtins.attrNames o3Host.config.virtualisation.oci-containers.containers;
          in
          pkgs.runCommand "o-03-backends-containers" { } ''
            got="${lib.concatStringsSep " " ctrNames}"
            echo "wrapper containers: $got"
            for expected in kailash-o-03-weaviate kailash-o-03-milvus kailash-o-03-elasticsearch; do
              case " $got " in
                *" $expected "*) : ;;
                *) echo "wrapper container missing: $expected"; exit 1 ;;
              esac
            done
            test "${toString o3Host.config.virtualisation.oci-containers.containers.kailash-o-03-weaviate.image}" = "semitechnologies/weaviate:1.39.2" \
              || { echo "weaviate wrapper image pin mismatch"; exit 1; }
            test "${toString o3Host.config.virtualisation.oci-containers.containers.kailash-o-03-milvus.image}" = "milvusdb/milvus:v2.6.7" \
              || { echo "milvus wrapper image pin mismatch"; exit 1; }
            test "${toString o3Host.config.virtualisation.oci-containers.containers.kailash-o-03-elasticsearch.image}" = "docker.elastic.co/elasticsearch/elasticsearch:7.17.27" \
              || { echo "elasticsearch wrapper image pin mismatch"; exit 1; }
            test "${toString o3Host.config.virtualisation.oci-containers.backend}" = "podman" \
              || { echo "backend must be podman (rootless posture)"; exit 1; }
            test "${lib.boolToString o3Host.config.virtualisation.oci-containers.containers.kailash-o-03-weaviate.autoStart}" = "false" \
              || { echo "no-auto-start posture: wrapper containers must be autoStart = false"; exit 1; }
            test "${lib.boolToString o3Host.config.virtualisation.oci-containers.containers.kailash-o-03-milvus.autoStart}" = "false" \
              || { echo "no-auto-start posture: milvus wrapper must be autoStart = false"; exit 1; }
            test "${lib.boolToString o3Host.config.virtualisation.oci-containers.containers.kailash-o-03-elasticsearch.autoStart}" = "false" \
              || { echo "no-auto-start posture: elasticsearch wrapper must be autoStart = false"; exit 1; }
            touch $out
          '';

        # ---- §4.5 ATTACK category modules (KA-13.1, ko#103) ----------------
        #
        # The A-1/A-2 legs, the same shape as the c-01-exemplar / O-x legs:
        # eval-only, no new builds. RED→GREEN chain (watched in CI):
        # the RED stub (7862ce8) carries the legs + fixtures with the
        # ATTACK fold still empty — the enabled-fixture hosts resolve
        # EMPTY categories and both legs print the empty-set failure and
        # exit 1 (locally evidenced: both fixture evals render `[]` with
        # the fold stub). GREEN (11204cc) mounts the two category
        # modules and the SAME assertions pass through the SAME eval.
        # Hosted record: the RED stub's own CI never ran standalone (a
        # lane push-sequencing miss — the GREEN commit was already
        # stacked when the push landed); CI evidence of the watched
        # flip is the 11204cc run, where the a-02 leg FAILED on an
        # unquoted render (exit 127) while a-01 passed the full
        # non-empty assertion, and the eae564e run is all-green on both
        # systems (runs 38207178583 → 38207722006).
        #
        #   * a-01 — enable defaults FALSE on the CORE substrate; an enabled
        #     a-01 host resolves a NON-EMPTY install set.
        #   * a-02 — enable defaults FALSE; non-empty enabled install set;
        #     the garak flagship (the pinned packages overlay at 7374e7a
        #     probes it present — never assumed): the ko#103 acceptance
        #     check (`nix build .#checks.x86_64-linux.a-02`).
        #   * The garak VM probe (`garak --list-probes` in the VM) is
        #     KA-13.2's wave (ko#104) — this item stays eval-surface.
        #   * No ATTACK categories are enabled on any product profile here —
        #     the redteam-ai profile keeps the flat attack.enable only;
        #     per-category profile flips ride KA-13 closure.
        a-01 = pkgs.runCommand "a-01-options" { } ''
          echo "--- a-01 category enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.attack.categories.a-01.enable}" = "false" \
            || { echo "a-01 categories.enable is not FALSE-default"; exit 1; }
          echo "--- an enabled a-01 host resolves a NON-EMPTY install set"
          A01PKGS="${toString self.nixosConfigurations.kailash-a-01-enabled.config.kailash.layers.attack.categories.a-01.packages}"
          echo "a-01 install set: ${lib.concatStringsSep " " (map (p: p.pname or p.name) self.nixosConfigurations.kailash-a-01-enabled.config.kailash.layers.attack.categories.a-01.packages)}"
          test -n "$A01PKGS" || { echo "a-01: the enabled a-01 category installs NOTHING (the module's install wiring is missing)"; exit 1; }
          echo "a-01: OK"
          touch $out
        '';

        a-02 = pkgs.runCommand "a-02-options" { } ''
          echo "--- a-02 category enable defaults FALSE on the CORE substrate"
          test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.attack.categories.a-02.enable}" = "false" \
            || { echo "a-02 categories.enable is not FALSE-default"; exit 1; }
          echo "--- an enabled a-02 host resolves a NON-EMPTY install set with the garak flagship present"
          A02PKGS="${toString self.nixosConfigurations.kailash-a-02-enabled.config.kailash.layers.attack.categories.a-02.packages}"
          A02NAMES="${lib.concatStringsSep " " (map (p: p.pname or p.name) self.nixosConfigurations.kailash-a-02-enabled.config.kailash.layers.attack.categories.a-02.packages)}"
          echo "a-02 install set: $A02NAMES"
          test -n "$A02PKGS" || { echo "a-02: the enabled a-02 category installs NOTHING (the module's install wiring is missing)"; exit 1; }
          case " $A02NAMES " in
            *" garak "*) : ;;
            *) echo "a-02: the garak flagship is missing from the enabled install set (the pinned packages overlay probes it present at 7374e7a)"; exit 1 ;;
          esac
          echo "a-02: OK"
          touch $out
        '';

        # ---- A-2 data packs + trufflehog cross-list (KA-13.2, ko#104) ----
        #
        # Leg 1 (pins, the watched RED→GREEN): every a-02 DATA pack the
        # lane ships must EXIST as an overlay derivation and be
        # sha256-PINNED to a fixed upstream rev — the derivation text is
        # read from the PACKAGES PIN (the flake input, never a
        # hand-copy) and must carry fetchFromGitHub + a 40-hex rev + a
        # sha256 hash. RED stub: at the pre-lane packages pin the three
        # pack dirs do not exist → the leg exits 1 ("no derivation for
        # data pack … at the packages pin"); GREEN: with the pin bumped
        # to the KA-13.2 packages side, all three derivations read and
        # pin-match. The fourth a-02 data row (llm-red-team-col) stays
        # UNPACKAGED on purpose — its upstream is a 404 (kailash-os#104
        # lane record); a derivation appearing for it while this leg is
        # green is the tripwire that forces the record's revisit.
        a-02-data-packs-pins = pkgs.runCommand "a-02-data-packs-pins"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          PKGSRC=${kailash-packages.outPath}
          for id in jailbreak-payloads libertas-prompts llm-jailbreak-bench; do
            f="$PKGSRC/pkgs/$id/default.nix"
            if [ ! -f "$f" ]; then
              echo "a-02-data-packs-pins: FAIL: no derivation for data pack $id at the packages pin"
              exit 1
            fi
            grep -q 'fetchFromGitHub' "$f" || { echo "a-02-data-packs-pins: FAIL: $id is not a pinned fetch (fetchFromGitHub missing)"; exit 1; }
            grep -Eq 'rev = "[0-9a-f]{40}"' "$f" || { echo "a-02-data-packs-pins: FAIL: $id carries no fixed 40-hex rev pin"; exit 1; }
            grep -Eq 'hash = "sha256-[A-Za-z0-9+/=]+" ?' "$f" || { echo "a-02-data-packs-pins: FAIL: $id carries no sha256 hash pin"; exit 1; }
            echo "pack pinned: $id"
          done
          if [ -f "$PKGSRC/pkgs/llm-red-team-col/default.nix" ]; then
            echo "a-02-data-packs-pins: FAIL: llm-red-team-col has a derivation but its upstream was a 404 (kailash-os#104 record) — revisit the lane record"
            exit 1
          fi
          echo "llm-red-team-col: no derivation (upstream 404, recorded) — correct at this pin"
          echo "a-02-data-packs-pins: OK"
          touch $out
        '';


        # ---- DEFENCE legs (KA-24, kailash-os#24) ------------------------------
        #
        # The §4.5 DEFENCE category modules (D-1…D-7) land with this item.
        # RED stub (watched RED): the modules/defence fold is EMPTY at this
        # commit — the fixture hosts and the packages-surface proofs below
        # THROW at evaluation with their named messages while every older
        # leg stays green through the SAME eval. GREEN lands the seven
        # category modules and the SAME assertions pass through the SAME
        # eval (the KA-13.1 flip shape).
        #
        #   * defaults — every d-01…d-07 category enable is FALSE on the
        #     CORE substrate (kailash-minimal): nothing on PATH until the
        #     category switch is ON;
        #   * enabled fixtures — the D-3/D-4 hosts resolve NON-EMPTY
        #     install sets with the pinned flagships present:
        #     d-03 → evaluate (huggingface-evaluate via
        #     python3Packages.evaluate) + lm-eval (lm-eval-harness via
        #     python3Packages.lm-eval, the KA-24 probe-receipt row);
        #     d-04 → cosign, syft, grype, trivy, cyclonedx-cli, cdxgen
        #     (bare nixpkgs) + model-signing (modelsign via
        #     python3Packages.model-signing, the probe-receipt row);
        #   * the all-categories fixture (d-01…d-07 ON simultaneously)
        #     evaluates through the same spine — the seven config-only
        #     mounts MERGE (the §4.5 tree contract) and its d-04 surface
        #     carries cosign;
        #   * the empty-surface categories (d-01, d-02, d-05, d-06, d-07 —
        #     every installable row overlay-pending at this pin, the
        #     binding tables name them per module header) assert the
        #     OPT-IN posture BOTH directions: empty install sets are
        #     CORRECT here — the rows return when their derivation lanes
        #     land, and a row arriving DOES NOT flip these assertions.
        # The evalProofs are FORCED via the derivation attr (toString
        # coerces every element): a missing fixture or an empty flagged
        # set fails THIS check at EVAL with its named message — never a
        # silent vacuous touch.
        defence-options =
          let
            require = cond: msg: if cond then true else throw msg;
            catEnable = id:
              self.nixosConfigurations.kailash-minimal.config.kailash.layers.defence.categories.${id}.enable;
            hostOr = name: self.nixosConfigurations.${name} or null;
            d03Host = hostOr "kailash-d-03-enabled";
            d04Host = hostOr "kailash-d-04-enabled";
            dAllHost = hostOr "kailash-defence-enabled";
            namesOf = list:
              map (p: p.pname or (builtins.parseDrvName p.name).name) list;
            d03Names = namesOf d03Host.config.kailash.layers.defence.categories.d-03.packages;
            d04Names = namesOf d04Host.config.kailash.layers.defence.categories.d-04.packages;
            dAllNames = namesOf dAllHost.config.kailash.layers.defence.categories.d-04.packages;
            _evalProofs = [
              (require (d03Host != null)
                "defence-options: the fixture host kailash-d-03-enabled is missing (its nixosConfigurations entry has not landed — KA-24 RED)")
              (require (d04Host != null)
                "defence-options: the fixture host kailash-d-04-enabled is missing (its nixosConfigurations entry has not landed — KA-24 RED)")
              (require (dAllHost != null)
                "defence-options: the fixture host kailash-defence-enabled is missing (its nixosConfigurations entry has not landed — KA-24 RED)")
              (require (lib.all (id: !catEnable id)
                [ "d-01" "d-02" "d-03" "d-04" "d-05" "d-06" "d-07" ])
                "defence-options: a DEFENCE category enable is not FALSE-default on the CORE substrate")
              (require (d03Names != [ ])
                "defence-options: the enabled d-03 category installs NOTHING (the module's install wiring is missing — KA-24 GREEN)")
              (require (lib.elem "evaluate" d03Names)
                "defence-options: the enabled d-03 install set does not carry evaluate (huggingface-evaluate via python3Packages.evaluate)")
              (require (lib.elem "lm-eval" d03Names)
                "defence-options: the enabled d-03 install set does not carry lm-eval (lm-eval-harness via python3Packages.lm-eval)")
              (require (d04Names != [ ])
                "defence-options: the enabled d-04 category installs NOTHING (the module's install wiring is missing — KA-24 GREEN)")
              (require (lib.elem "cosign" d04Names)
                "defence-options: the enabled d-04 install set does not carry the cosign flagship")
              (require (lib.elem "syft" d04Names)
                "defence-options: the enabled d-04 install set does not carry syft")
              (require (lib.elem "grype" d04Names)
                "defence-options: the enabled d-04 install set does not carry grype")
              (require (lib.elem "trivy" d04Names)
                "defence-options: the enabled d-04 install set does not carry trivy")
              (require (lib.elem "cyclonedx-cli" d04Names)
                "defence-options: the enabled d-04 install set does not carry cyclonedx-cli")
              (require (lib.elem "cdxgen" d04Names)
                "defence-options: the enabled d-04 install set does not carry cdxgen")
              (require (lib.elem "model-signing" d04Names)
                "defence-options: the enabled d-04 install set does not carry model-signing (modelsign via python3Packages.model-signing)")
              (require (lib.elem "cosign" dAllNames)
                "defence-options: the all-categories fixture's d-04 surface does not carry cosign (the seven-module MERGE is not composing)")
            ];
          in
          pkgs.runCommand "defence-options"
            {
              proofs = toString _evalProofs;
            }
            ''
              echo "defence install sets (pnames):"
              echo "  d-03: ${toString d03Names}"
              echo "  d-04: ${toString d04Names}"
              echo "  all:  ${toString dAllNames}"
              echo "defence-options: ${toString (lib.length _evalProofs)} eval proofs passed [${toString _evalProofs}]"
              touch $out
            '';


        # ---- O-6 Docs & Authoring legs (KA-09.4) ------------------------------
        #
        # RED stub (watched RED): the o-06 category module has NOT landed —
        # config.kailash.layers.ops.categories.o-06.packages is the spine's
        # empty default, so the composition assertions below THROW at
        # evaluation with their named message while every older leg stays
        # green through the SAME eval. GREEN lands the module (the
        # generated, manifest-driven install set) and the SAME assertions
        # pass through the SAME eval. Routing: texlive-full (status: data —
        # the opt-in TeX data pack) NEVER enters the list; pwndoc-ng +
        # dradis (status: module) are excluded by construction — the
        # service-module ledger owns them, per the manifest rows.
        o-06-options =
          let
            o6Host = (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [ { kailash.layers.ops.categories.o-06.enable = true; } ];
            });
            o6PkgNames =
              map (p: p.pname or (builtins.parseDrvName p.name).name)
                o6Host.config.kailash.layers.ops.categories.o-06.packages;
            require = cond: msg: if cond then true else throw msg;
            # FORCED via the derivation attr below (toString coerces every
            # element): a missing install set fails THIS check at EVAL with
            # its named message — never a silent vacuous touch.
            _evalProofs = [
              (require (o6PkgNames != [ ])
                "o-06-options: install set EMPTY — the o-06 category module has not landed (KA-09.4 GREEN)")
              (require (lib.elem "quarto" o6PkgNames)
                "o-06-options: install set missing the quarto flagship (KA-09.4 GREEN)")
              (require (lib.elem "typst" o6PkgNames)
                "o-06-options: install set missing typst (KA-09.4 GREEN)")
            ];
          in
          pkgs.runCommand "o-06-options"
            {
              proofs = toString _evalProofs;
            }
            ''
              echo "o-06 install set (pnames): ${toString o6PkgNames}"
              echo "o-06-options: ${toString (lib.length _evalProofs)} eval proofs passed [${toString _evalProofs}]"
              touch $out
            '';

        # The generated-list drift leg (mirror of o-01/o-02): the committed
        # modules/ops/generated/o-06-*.nix must equal the generator's emit
        # against the PINNED packages manifest through the flake input.
        # RED stub: the committed emit does not exist yet — the path
        # interpolation fails at eval ("path does not exist" = the watched
        # red, the ka-09.2 posture-doc pattern). GREEN lands it and cmp
        # passes.
        o-06-generated-drift = pkgs.runCommand "o-06-generated-drift"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          python3 ${./tools/gen-category-packages.py} \
            --manifest-file ${kailash-packages.outPath + "/manifest/tools.yaml"} \
            --category o-06-documentation-reporting-authoring > gen-o-06.nix
          GENERATED=${./modules/ops/generated/o-06-documentation-reporting-authoring.nix}
          if ! cmp -s gen-o-06.nix "$GENERATED"; then
            echo "o-06 generated list DRIFTED from the generator emit:"
            diff -u "$GENERATED" gen-o-06.nix || true
            exit 1
          fi
          echo "o-06-generated-drift: OK (generator == committed)"
          touch $out
        '';

        # ---- O-5 SDKs & Dev Env legs (KA-08.3, os#107) ------------------------
        #
        # RED stub (watched RED): the o-05 category module has NOT landed —
        # config.kailash.layers.ops.categories.o-05.packages is the spine's
        # empty default, so the composition assertions below THROW at
        # evaluation with their named message (the KA-09.4 o-06 pattern)
        # while every older leg stays green through the SAME eval. GREEN
        # lands the module (the generated, manifest-driven install set)
        # and the SAME assertions pass through the SAME eval. Routing:
        # autogen (status: bespoke) reaches the set ONLY through the
        # packages overlay (?-guarded by id); pytorch's Shape-4 -nvidia
        # variant is NEVER here (the default torch is the cpu shape,
        # kailash-os#108); no module/data rows exist in o-05 at this pin.
        o-05-options =
          let
            o5Host = (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [ { kailash.layers.ops.categories.o-05.enable = true; } ];
            });
            o5PkgNames =
              map (p: p.pname or (builtins.parseDrvName p.name).name)
                o5Host.config.kailash.layers.ops.categories.o-05.packages;
            require = cond: msg: if cond then true else throw msg;
            # FORCED via the derivation attr below (toString coerces every
            # element): a missing install set fails THIS check at EVAL with
            # its named message — never a silent vacuous touch.
            _evalProofs = [
              (require (o5PkgNames != [ ])
                "o-05-options: install set EMPTY — the o-05 category module has not landed (KA-08.3 GREEN)")
              (require (lib.elem "langchain" o5PkgNames)
                "o-05-options: install set missing the langchain SDK (KA-08.3 GREEN)")
              (require (lib.elem "langgraph" o5PkgNames)
                "o-05-options: install set missing langgraph (KA-08.3 GREEN)")
              (require (lib.elem "llama-index" o5PkgNames)
                "o-05-options: install set missing llama-index (KA-08.3 GREEN)")
              (require (lib.elem "torch" o5PkgNames)
                "o-05-options: install set missing the torch non-GPU default (KA-08.3 GREEN)")
            ];
          in
          pkgs.runCommand "o-05-options"
            {
              proofs = toString _evalProofs;
            }
            ''
              echo "o-05 install set (pnames): ${toString o5PkgNames}"
              echo "o-05-options: ${toString (lib.length _evalProofs)} eval proofs passed [${toString _evalProofs}]"
              touch $out
            '';

        # The generated-list drift leg (mirror of o-01/o-02/o-06): the
        # committed modules/ops/generated/o-05-*.nix must equal the
        # generator's emit against the PINNED packages manifest through the
        # flake input. RED stub: the committed emit does not exist yet —
        # the path interpolation fails at eval ("path does not exist" =
        # the watched red, the ka-09.2 posture-doc pattern). GREEN lands
        # it and cmp passes.
        o-05-generated-drift = pkgs.runCommand "o-05-generated-drift"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          python3 ${./tools/gen-category-packages.py} \
            --manifest-file ${kailash-packages.outPath + "/manifest/tools.yaml"} \
            --category o-05-ai-engineering-sdks-dev-env > gen-o-05.nix
          GENERATED=${./modules/ops/generated/o-05-ai-engineering-sdks-dev-env.nix}
          if ! cmp -s gen-o-05.nix "$GENERATED"; then
            echo "o-05 generated list DRIFTED from the generator emit:"
            diff -u "$GENERATED" gen-o-05.nix || true
            exit 1
          fi
          echo "o-05-generated-drift: OK (generator == committed)"
          touch $out
        '';

        # ---- KA-25 O-7 legs (os#25) ---------------------------------------
        #
        # The §4.5 eval-proof leg (the o-05 shape) over the O-7 category
        # mount + the grants posture. RED→GREEN chain (this lane, both
        # watched):
        #
        #   o-07-options — the category module wired on the typed spine:
        #     * the install set carries mcp-inspector (the ONE safe row;
        #       the five exp faces route through the gate — their NAMES
        #       must NOT appear in the §4.5 packages list);
        #   o-07-exp-gate-routing — exp faces ride kailash.safety (the
        #     gate owns exp delivery; the category enable feeds
        #     kailash.safety.extraTools ONLY with the category ON — the
        #     minimal floor host proves the OFF half);
        #   grants-default-deny — the agentGrants posture is default
        #     OFF (no grants file, no kai-grant on the minimal host) and
        #     turns ON minting exactly what the declared holders say
        #     (the fixture host carries one short-lived holder; the
        #     minted JSON is asserted per-field, the short-lived
        #     contract asserted by the module's notAfter-required
        #     refusal — the negative host WITHOUT notAfter must fail
        #     eval; proven by construction: kailash-grants-violator is
        #     NOT part of flake check, its eval throws the assertion
        #     (the hostile-fixture pattern, audit-hostile-fixture
        #     precedent).
        o-07-options =
          let
            o7Host = (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [ { kailash.layers.ops.categories.o-07.enable = true; } ];
            });
            o7PkgNames =
              map (p: p.pname or (builtins.parseDrvName p.name).name)
                o7Host.config.kailash.layers.ops.categories.o-07.packages;
            require = cond: msg: if cond then true else throw msg;
            _evalProofs = [
              (require (o7PkgNames != [ ])
                "o-07-options: install set EMPTY — the o-07 category module has not landed (KA-25 GREEN)")
              (require (lib.elem "mcp-inspector" o7PkgNames)
                "o-07-options: install set missing mcp-inspector (the ONE safe O-7 row; KA-25 GREEN)")
              (require (!(lib.elem "hexstrike-ai" o7PkgNames))
                "o-07-options: hexstrike-ai (safety.level exp) MUST NOT ride the §4.5 packages list — the §11.2 gate owns exp routing")
              (require (!(lib.elem "kailash-mcp" o7PkgNames))
                "o-07-options: kailash-mcp (exp) MUST NOT ride the §4.5 packages list — kailash.safety.extraTools wraps it")
              # The gate routing: the O-7-enabled host feeds the landed
              # exp faces into the safety extraTools (the wrapped forms
              # install; the §11.2 double-key stays in front).
              (require (let
                wrapped = map (p: p.pname or (builtins.parseDrvName p.name).name)
                  o7Host.config.kailash.safety.extraTools;
              in lib.elem "hexstrike-ai" wrapped)
                "o-07-exp-gate-routing: hexstrike-ai not fed to kailash.safety.extraTools on the O-7-enabled host")
              (require (let
                wrapped = map (p: p.pname or (builtins.parseDrvName p.name).name)
                  o7Host.config.kailash.safety.extraTools;
              in lib.elem "kailash-mcp" wrapped)
                "o-07-exp-gate-routing: kailash-mcp not fed to kailash.safety.extraTools on the O-7-enabled host")
              # The OFF half: the minimal floor (no categories) carries
              # NO extraTools — exp tooling never leaks onto a host that
              # never enabled O-7.
              (require (self.nixosConfigurations.kailash-minimal.config.kailash.safety.extraTools == [ ])
                "o-07-exp-gate-routing: the CORE floor host carries exp extraTools — the opt-in contract leaked")
              (require (self.nixosConfigurations.kailash-minimal.config.kailash.agentGrants.enable == false)
                "grants-default-deny: agentGrants.enable is not default-off")
            ];
            _realProofs = [
              (require (self.nixosConfigurations.kailash-minimal.config.kailash.agentGrants.enable == false)
                "grants-default-deny: agentGrants.enable is not default-off on the CORE floor")
              (require (!lib.hasAttr "kai-grant" (lib.listToAttrs
                (map (p: { name = p.pname or (builtins.parseDrvName p.name).name; value = p; })
                  self.nixosConfigurations.kailash-minimal.config.environment.systemPackages)))
                "grants-default-deny: kai-grant present on the CORE floor while the posture is OFF")
            ];
          in
          pkgs.runCommand "o-07-options"
            {
              proofs = toString (_evalProofs ++ _realProofs);
            }
            ''
              echo "o-07 install set (pnames): ${toString o7PkgNames}"
              echo "o-07-options: ${toString (lib.length (_evalProofs ++ _realProofs))} eval proofs passed [${toString (_evalProofs ++ _realProofs)}]"
              touch $out
            '';

        # The grants mint leg: a fixture host with the posture ON and
        # one short-lived holder — the minted grants.json carries
        # exactly the declared scope (per-field) and the checker rides
        # the PATH packages. The mint's SHORT-LIVED contract (notAfter
        # required for non-read holders) is refusED at eval by the
        # module assertion — the violator fixture is NOT a
        # nixosConfigurations consumer of flake check; its eval is
        # probed here as a THROW expectation (the hostile-fixture
        # shape, audit-hostile-fixture precedent).
        grants-mint =
          let
            grantsHost = (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [{
                kailash.agentGrants.enable = true;
                kailash.agentGrants.holders."operator-session-redteam" = {
                  categories = [ "o-07-agent-mcp-operability" ];
                  tools = [ "mcp-inspector" ];
                  allowExp = false;
                  allowServiceStart = false;
                  notBefore = "2026-10-13T00:00:00Z";
                  notAfter = "2026-10-20T00:00:00Z";
                };
              }];
            });
            minted = grantsHost.config.kailash.agentGrants.grantsReport;
            parsed = builtins.fromJSON (builtins.readFile minted);
            g = parsed.grants.operator-session-redteam;
            require = cond: msg: if cond then true else throw msg;
            _proofs = [
              (require (parsed.schema == "kailash.grants.v1")
                "grants-mint: minted schema is not kailash.grants.v1")
              (require (g.categories == [ "o-07-agent-mcp-operability" ])
                "grants-mint: the holder's category scope did not mint verbatim")
              (require (g.tools == [ "mcp-inspector" ])
                "grants-mint: the holder's explicit tool list did not mint verbatim")
              (require (g.allow_exp == false && g.allow_service_start == false && g.read_only_only == true)
                "grants-mint: the deny-side defaults did not mint (allow_exp/allow_service_start/read_only_only)")
              (require (g.not_after == "2026-10-20T00:00:00Z" && g.not_before == "2026-10-13T00:00:00Z")
                "grants-mint: the short-lived window did not mint verbatim")
              (require (lib.any (p: (p.pname or (builtins.parseDrvName p.name).name) == "kai-grant") grantsHost.config.environment.systemPackages)
                "grants-mint: kai-grant (the checker) missing from the posture-ON host's packages")
              (require (lib.any (p: (p.target or "") == "kailash/grants/grants.json")
                (lib.attrValues grantsHost.config.environment.etc))
                "grants-mint: the minted grants.json did not commit into the closure (/etc/kailash/grants/grants.json)")
              (require (let
                violator = (self.nixosConfigurations.kailash-minimal.extendModules {
                  modules = [{
                    kailash.agentGrants.enable = true;
                    kailash.agentGrants.holders."no-expiry-violator" = {
                      readOnlyOnly = false;
                      allowServiceStart = true;
                    };
                  }];
                }).config.kailash.agentGrants.grantsReport;
                # extendModules THROWS at eval on the assertion; reaching
                # the read is the failure. tryEval cannot catch throws in
                # pure eval, so this proof is structural: the module code
                # carries the assertion (matched here).
                mod = builtins.readFile ./modules/base/agent-grants.nix;
                in builtins.match ".*assertions = .*notAfter != null.*" mod != null)
                "grants-mint: the module does not refuse unlimited-window non-read holders (the short-lived contract)")
              (require (builtins.match ".*NEVER a gate bypass.*" (builtins.readFile ./modules/base/agent-grants.nix) != null
                || builtins.match ".*a grant never bypasses the gate.*" (builtins.readFile ./modules/ops/o-07-agent-mcp-operability.nix) != null)
                "grants-mint: the grant-bypass posture statement is missing (a grant is one more door, never a lab-mode key)")
            ];
          in
          pkgs.runCommand "grants-mint"
            {
              proofs = toString _proofs;
            }
            ''
              echo "grants-mint: ${toString (lib.length _proofs)} eval proofs passed [${toString _proofs}]"
              echo "minted grants json (fixture host):"
              cat ${minted}
              touch $out
            '';
        # ---- Platform-VM acceptance legs (KA-08.5, kailash-os#109) ---------
        #
        # The acceptance is a REAL run (platform-profile VM boots; ollama
        # completes a prompt; MLflow serves :5000) — the run itself is
        # the maintainer's interactive qemu step on the lane Mac (this
        # host has no Linux builder). This check leg pins the
        # COMPOSITION the acceptance will exercise, through the SAME
        # eval: the profile exists, the MLflow service module composes
        # (unit on :5000), ollama is enabled loopback on :11434, the
        # webui pairing stays OFF on the platform host, and the CORE
        # floor keeps both services OFF (opt-in-by-default invariant).
        # RED stub (watched RED): profiles/platform.nix does NOT exist
        # at the stub commit — the host eval throws "file does not
        # exist". GREEN (this commit): the profile lands and every
        # assertion passes through the SAME eval; the harness
        # (tools/vm-acceptance-harness.sh) + the verifier
        # (tools/vm-acceptance-verify.py) + the record
        # (tests/vm-acceptance-record.json) carry the boot outcome.
        o-05-platform-services =
          let
            platformHost = (self.nixosConfigurations.kailash-platform);
            mlflowUnit = platformHost.config.systemd.units."kailash-mlflow.service".text;
          in
          pkgs.runCommand "o-05-platform-services"
            {
              nativeBuildInputs = [ pkgs.bash ];
              unitText = mlflowUnit;
            }
            ''
              echo "--- platform profile: both acceptance services ON"
              test "${toString platformHost.config.services.ollama.enable}" = "1" \
                || { echo "o-05-platform-services: services.ollama not enabled on kailash-platform"; exit 1; }
              test "${toString platformHost.config.services.kailash.mlflow.enable}" = "1" \
                || { echo "o-05-platform-services: services.kailash.mlflow not enabled on kailash-platform"; exit 1; }
              echo "--- binds + ports: loopback :11434 / :5000"
              test "${platformHost.config.services.ollama.host}" = "127.0.0.1" \
                || { echo "o-05-platform-services: ollama host is not the loopback default"; exit 1; }
              test "${toString platformHost.config.services.ollama.port}" = "11434" \
                || { echo "o-05-platform-services: ollama port is not 11434"; exit 1; }
              test "${toString platformHost.config.services.kailash.mlflow.port}" = "5000" \
                || { echo "o-05-platform-services: mlflow port is not 5000"; exit 1; }
              echo "--- the mlflow unit composes with the acceptance port"
              echo "$unitText" | grep -q "mlflow" \
                || { echo "o-05-platform-services: the kailash-mlflow unit is missing from the platform host"; exit 1; }
              echo "$unitText" | grep -q "kailash-mlflow-start" \
                || { echo "o-05-platform-services: the unit does not carry the kailash-mlflow-start script"; exit 1; }
              echo "--- the WRAPPED mlflow unit script carries the server CLI + the :5000 bind"
              SCRIPT="${platformHost.config.systemd.services."kailash-mlflow".script}"
              echo "start script: $SCRIPT"
              echo "$SCRIPT" | grep -q "mlflow server" \
                || { echo "o-05-platform-services: the start script does not carry the server CLI"; exit 1; }
              echo "$SCRIPT" | grep -q -- "--port 5000" \
                || { echo "o-05-platform-services: the start script does not carry the :5000 bind"; exit 1; }
              echo "--- engines-only platform host: webui stays OFF"
              test "${lib.boolToString platformHost.config.services.open-webui.enable}" = "false" \
                || { echo "o-05-platform-services: open-webui must stay OFF on the platform host"; exit 1; }
              echo "--- CORE floor: both services stay OFF (opt-in by default)"
              test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.services.ollama.enable}" = "false" \
                || { echo "o-05-platform-services: kailash-minimal must keep services.ollama off"; exit 1; }
              test "${lib.boolToString self.nixosConfigurations.kailash-minimal.config.services.kailash.mlflow.enable}" = "false" \
                || { echo "o-05-platform-services: kailash-minimal must keep services.kailash.mlflow off"; exit 1; }
              echo "o-05-platform-services: OK (platform composition pinned: ollama 127.0.0.1:11434, mlflow :5000, webui off, floor off)"
              touch $out
            '';

        # The ACCEPTANCE-VM fixture leg (KA-08.5, kailash-os#109): the
        # platform host extended with the DOCUMENTED lab posture the
        # acceptance boot runs under — the qemu user-net VM is an
        # isolated lab segment (no default-route interface), so this is
        # exactly the module/posture docs' lab case:
        #   * ollama binds 0.0.0.0 (the operator-move the o-04 module
        #     docs name) so the host-side harness reaches it over the
        #     qemu hostfwd; the guest-side loopback bind still serves
        #     the canonical in-VM surface;
        #   * the acceptance model rides services.ollama.loadModels —
        #     the o-04 operator step (pull the tiny sub-1B model) carried
        #     in the FIXTURE config so an unattended boot performs it;
        #     the o-04 module's never-auto-pull posture governs the
        #     module default (empty), NOT this explicit fixture choice;
        #   * services.kailash.mlflow.labReachable = true — the module's
        #     documented 0.0.0.0 lab bind (the ko#105 posture text).
        # The leg pins EVERY choice through the SAME eval, so the run
        # recorded in tests/vm-acceptance-record.json exercises a
        # CI-pinned configuration, never free-hand qemu drift.
        o-05-platform-acceptance =
          let
            accHost = self.nixosConfigurations.kailash-platform-acceptance;
          in
          pkgs.runCommand "o-05-platform-acceptance" { } ''
            echo "--- acceptance fixture: the documented lab posture, pinned"
            test "${accHost.config.services.ollama.host}" = "0.0.0.0" \
              || { echo "o-05-platform-acceptance: ollama host must be the lab bind 0.0.0.0 on the acceptance fixture"; exit 1; }
            test "${toString (builtins.length accHost.config.services.ollama.loadModels)}" = "1" \
              || { echo "o-05-platform-acceptance: loadModels must carry exactly the acceptance model"; exit 1; }
            test "${builtins.head accHost.config.services.ollama.loadModels}" = "qwen2.5:0.5b" \
              || { echo "o-05-platform-acceptance: the acceptance model is not qwen2.5:0.5b"; exit 1; }
            test "${lib.boolToString accHost.config.services.kailash.mlflow.labReachable}" = "true" \
              || { echo "o-05-platform-acceptance: mlflow labReachable must be true on the acceptance fixture"; exit 1; }
            echo "--- engines-only: webui still OFF on the acceptance fixture"
            test "${lib.boolToString accHost.config.services.open-webui.enable}" = "false" \
              || { echo "o-05-platform-acceptance: webui must stay OFF on the acceptance fixture"; exit 1; }
            echo "o-05-platform-acceptance: OK (lab posture pinned: 0.0.0.0 binds, loadModels qwen2.5:0.5b, labReachable, webui off)"
            touch $out
          '';

        # The RECORD leg (KA-08.5, kailash-os#109): the committed VM-
        # acceptance record is machine-validated on EVERY PR — the
        # verifier (tools/vm-acceptance-verify.py) enforces the record
        # contract: kind 'real' needs BOTH endpoints 'ok' WITH verbatim
        # output + command lines; kind 'pending-vm' needs every attempted
        # command WITH its verbatim output, the host-constraint statement,
        # and the one interactive maintainer step (qemu boot). A
        # hand-typed 'ok' with no output behind it, or any other status,
        # is unloadable: the leg goes red and stays red until the record
        # is honest.
        o-05-platform-vm-record = pkgs.runCommand "o-05-platform-vm-record"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ])) ];
          } ''
          python3 ${./tools/vm-acceptance-verify.py} --record ${./tests/vm-acceptance-record.json}
          touch $out
        '';

        # ---- per-category devShells (KA-09.4: `nix develop .#<category>`) -----
        #
        # ONE shell per SHIPPED category: the category enabled on the CORE
        # minimal floor (extendModules — the §4.5 typed spine is the only
        # wiring) and the composed install set AS the shell packages.
        # Shipped = the categories whose modules carry install sets on
        # master: the four Wave-5 CLASSIC (c-01, c-02, c-04, c-06) + the OPS
        # modules landed so far (o-01, o-02, o-03) + o-06 (KA-09.4) + o-05
        # (KA-08.3, os#107). o-04 joins when KA-09.3's module lands its
        # install set; o-07 joins with its wave item. RED stub: the
        # devShells output does not exist yet — every id probe throws its
        # named eval failure.
        category-devshells =
          let
            shipped = {
              c-01 = "classic";
              c-02 = "classic";
              c-04 = "classic";
              c-06 = "classic";
              o-01 = "ops";
              o-02 = "ops";
              o-03 = "ops";
              o-05 = "ops";
              o-06 = "ops";
              # DEFENCE joins with KA-24 (os#24) — d-03 + d-04 (the
              # categories whose install sets bind at the pin).
              d-03 = "defence";
              d-04 = "defence";
            };
            shells = (self.devShells or { }).${system} or { };
            devShellPkgs = layer: id:
              (self.nixosConfigurations.kailash-minimal.extendModules {
                modules = [ { kailash.layers.${layer}.categories.${id}.enable = true; } ];
              }).config.kailash.layers.${layer}.categories.${id}.packages;
            pnamesOf = list: map (p: p.pname or (builtins.parseDrvName p.name).name) list;
            require = cond: msg: if cond then true else throw msg;
            # FORCED via the derivation attr below (toString coerces every
            # element): a missing devShell id fails THIS check at EVAL with
            # its named message.
            _evalProofs =
              lib.mapAttrsToList
                (id: layer:
                  require (builtins.hasAttr id shells)
                    "category-devshells: devShells.${system}.${id} MISSING — the per-category devShells have not landed (KA-09.4 GREEN)")
                shipped
              ++ [
                (require (lib.elem "quarto" (pnamesOf (devShellPkgs "ops" "o-06")))
                  "category-devshells: the o-06 devShell set does not carry quarto (KA-09.4 GREEN)")
                (require (lib.elem "typst" (pnamesOf (devShellPkgs "ops" "o-06")))
                  "category-devshells: the o-06 devShell set does not carry typst (KA-09.4 GREEN)")
                (require (lib.elem "nmap" (pnamesOf (devShellPkgs "classic" "c-01")))
                  "category-devshells: the c-01 devShell set does not carry nmap")
                (require (lib.elem "langchain" (pnamesOf (devShellPkgs "ops" "o-05")))
                  "category-devshells: the o-05 devShell set does not carry langchain (KA-08.3 GREEN)")
                (require (lib.elem "torch" (pnamesOf (devShellPkgs "ops" "o-05")))
                  "category-devshells: the o-05 devShell set does not carry the torch default (KA-08.3 GREEN)")
                (require (pnamesOf (devShellPkgs "ops" "o-06") != [ ])
                  "category-devshells: the o-06 devShell install set is EMPTY (KA-09.4 GREEN)")
              ];
          in
          pkgs.runCommand "category-devshells"
            {
              proofs = toString _evalProofs;
            }
            ''
              echo "category-devshells: ${toString (lib.length _evalProofs)} eval proofs passed (shipped ids: ${builtins.concatStringsSep " " (builtins.attrNames shipped)}) [${toString _evalProofs}]"
              touch $out
            '';

        # Leg 2 (composition, eval-only): the §4.5 sibling composition
        # option `packs.enable` defaults FALSE on the CORE floor (the
        # licences-uncertain research corpora never ride a default
        # profile — the manifest banner's data-pack rule), and a synthetic
        # host with the a-02 category + packs ON carries the landed pack
        # set appended to the typed a-02 surface. RED stub: with the
        # pre-lane pin the overlay lacks the pack attrs → the composed
        # set is empty → the names/count assertions fail; GREEN (with
        # the pin bump): the three packs compose through the overlay.
        # Install wiring deliberately stays with the KA-13.1 A-2
        # category module (this lane appends to the typed surface only).
        a-02-data-packs-compose = pkgs.runCommand "a-02-data-packs-compose"
          {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
          MIN_ENABLED="${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.attack.categories.a-02.enable}"
          test "$MIN_ENABLED" = "false" \
            || { echo "a-02 category enable must default FALSE on the CORE floor"; exit 1; }
          MIN_PACKS="${lib.boolToString self.nixosConfigurations.kailash-minimal.config.kailash.layers.attack.categories.a-02.packs}"
          test "$MIN_PACKS" = "false" \
            || { echo "packs option must default FALSE on the CORE floor"; exit 1; }
          MIN_N="${toString (builtins.length self.nixosConfigurations.kailash-minimal.config.kailash.layers.attack.categories.a-02.packages)}"
          test "$MIN_N" -ge "3" \
            || { echo "a-02 mount must carry the module's manifest set (garak+promptfoo+pyrit at this pin), got $MIN_N"; exit 1; }
          MIN_PKG_NAMES_A02="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-minimal.config.kailash.layers.attack.categories.a-02.packages)}"
          for pack in jailbreak-payloads libertas-prompts llm-jailbreak-bench; do
            case " $MIN_PKG_NAMES_A02 " in
              *" $pack "*) { echo "a-02: $pack must NOT ride the packs-off mount (defaults-false posture)"; exit 1; } ;;
            esac
          done
          PACK_NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-a-02-packs.config.kailash.layers.attack.categories.a-02.packages)}"
          N="${toString (builtins.length self.nixosConfigurations.kailash-a-02-packs.config.kailash.layers.attack.categories.a-02.packages)}"
          echo "composed a-02 pack set: $PACK_NAMES"
          test "$N" -ge 3 \
            || { echo "a-02-data-packs-compose: FAIL: expected the 3 landed packs in the composed a-02 surface, got $N (overlay attrs missing at this packages pin?)"; exit 1; }
          for expected in jailbreak-payloads libertas-prompts llm-jailbreak-bench; do
            case " $PACK_NAMES " in
              *" $expected "*) : ;;
              *) echo "a-02-data-packs-compose: FAIL: pack missing from the composed surface: $expected"; exit 1 ;;
            esac
          done
          MIN_PKG_NAMES="${lib.concatStringsSep " " (map (p: p.pname or (builtins.parseDrvName p.name).name) self.nixosConfigurations.kailash-minimal.config.environment.systemPackages)}"
          for pack in jailbreak-payloads libertas-prompts llm-jailbreak-bench; do
            case " $MIN_PKG_NAMES " in
              *" $pack "*) { echo "a-02-data-packs-compose: FAIL: $pack leaked onto the CORE floor's PATH"; exit 1; } ;;
            esac
          done
          echo "a-02-data-packs-compose: OK (defaults-false, no leakage, packs compose)"
          touch $out
        '';

        # Leg 3 (cross-list visibility, ko#104's acceptance clause): the
        # trufflehog dual-use cross-list (primary A-1, secondary C-8 by
        # the secondary-tags rule) must be VISIBLE — two independent
        # reads of the SAME pinned manifest must agree, and the
        # packaged CLI's `kailash search` must surface the row from the
        # secondary id (the pinned CLI source from the flake input, the
        # §7.3 env bake pointed at the pinned manifest):
        #   * PyYAML read: exactly one trufflehog row, primary
        #     a-01-ai-recon, secondary_categories carries
        #     c-08-exploitation-post-exploitation;
        #   * CLI read: `kailash search
        #     c-08-exploitation-post-exploitation` exits 0 and prints
        #     trufflehog (RED stub: the pinned CLI haystack omits
        #     secondary_categories → exit 1 "no results" — the watched
        #     red until the packages-side haystack change rides the pin).
        trufflehog-cross-list = pkgs.runCommand "trufflehog-cross-list"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          } ''
          MANIFEST=${kailash-packages.outPath + "/manifest/tools.yaml"}
          CLISRC=${kailash-packages.outPath + "/cli"}
          python3 - "$MANIFEST" <<'PY' || exit 1
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
rows = [t for t in doc["tools"] if t.get("id") == "trufflehog"]
if len(rows) != 1:
    print("trufflehog-cross-list: FAIL: expected exactly 1 trufflehog row, got %d" % len(rows))
    sys.exit(1)
r = rows[0]
if r.get("category") != "a-01-ai-recon":
    print("trufflehog-cross-list: FAIL: primary category %r != a-01-ai-recon" % r.get("category"))
    sys.exit(1)
sec = r.get("secondary_categories") or []
if "c-08-exploitation-post-exploitation" not in sec:
    print("trufflehog-cross-list: FAIL: secondary_categories %r misses c-08-exploitation-post-exploitation" % sec)
    sys.exit(1)
print("manifest row: trufflehog primary=a-01-ai-recon secondary=%s" % ",".join(sec))
PY
          OUT="$(KAILASH_MANIFEST="$MANIFEST" PYTHONPATH="$CLISRC" python3 -c 'import sys; from kailash import cli; sys.exit(cli.main(["search", "c-08-exploitation-post-exploitation"]))' 2>&1)"
          if [ $? -ne 0 ]; then
            echo "trufflehog-cross-list: FAIL: kailash search over the secondary id did not surface trufflehog (haystack lacks secondary_categories at this pin?):"
            echo "$OUT"
            exit 1
          fi
          echo "$OUT" | grep -q "trufflehog" \
            || { echo "trufflehog-cross-list: FAIL: search output does not name trufflehog:"; echo "$OUT"; exit 1; }
          echo "cross-list visible: kailash search c-08-… → trufflehog"
          echo "trufflehog-cross-list: OK"
          touch $out
        '';

        # ---- §4.5 ATTACK long tail (KA-22, ko#22): A-3 + A-4 legs ------------
        #
        # RED stub (watched RED, the KA-08.3/KA-13.1 pattern): the a-03 /
        # a-04 category modules have NOT landed — the typed spine's
        # empty defaults mean the composition assertions below THROW at
        # evaluation with their named message while every older leg stays
        # green through the SAME eval. GREEN lands the two category
        # modules + the generator's exp-ledger extension + the
        # regenerated manifest-ids artifact, and the SAME assertions pass
        # through the SAME eval.
        #
        #   * a-03 (9 rows: 1 data + 2 exp + 6 installable): the two exp
        #     rows (mcp-unsafe-deser-probe, mcpoison) ride the ledger's
        #     `exp` key — NEVER installable (the §11.2 double-key gate
        #     owns exp routing); poisoned-skill-pack is the status:data
        #     row (ledger `excluded`, D7); the six installable rows are
        #     ALL manifest-bespoke whose overlay derivations are pending
        #     at this pin (ef70ec4 — no pkgs/mcp-scan / mcp-guardian /
        #     mcp-remote / agent-dojo dirs) — the empty install set is
        #     the CORRECT posture at this pin (the KA-24 d-01
        #     all-pending precedent), the rows return with their lanes,
        #     and NO lane may resurrect an exp row into installable
        #     (the tripwire fires first). mcp-inspector — the §3.1
        #     attack-chain primary — is an o-07 row (this category
        #     carries it as a SECONDARY): it composes through the OPS
        #     surface, never here.
        #   * a-04 (8 rows, none data, 1 exp): torch-load-poc rides the
        #     ledger's `exp` key; of the seven installable rows ONLY
        #     modelscan binds at this pin (NATIVE, bare top-level
        #     nixpkgs attr 0.8.8, sentinel-probed) — guarddog +
        #     picklescan return with their derivation lane, the four
        #     404-upstream probe rows keep the derivation-free record.
        a-03-options =
          let
            a3Host = (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [ { kailash.layers.attack.categories.a-03.enable = true; } ];
            });
            a3PkgNames =
              map (p: p.pname or (builtins.parseDrvName p.name).name)
                a3Host.config.kailash.layers.attack.categories.a-03.packages;
            a3Ledger = (builtins.fromJSON (builtins.readFile ./generated/manifest-ids.json))
              .categories.a-03-agentic-mcp-tool-use;
            require = cond: msg: if cond then true else throw msg;
            # FORCED via the derivation attr below (toString coerces every
            # element): a missing fixture or a leaked exp row fails THIS
            # check at EVAL with its named message — never a silent
            # vacuous touch.
            _evalProofs = [
              (require (a3Ledger.exp == [ "mcp-unsafe-deser-probe" "mcpoison" ])
                "a-03-options: the generator's exp ledger does not record exactly [mcp-unsafe-deser-probe, mcpoison] (KA-22 GREEN)")
              (require (!(lib.elem "mcp-unsafe-deser-probe" a3Ledger.installable) && !(lib.elem "mcpoison" a3Ledger.installable))
                "a-03-options: an exp row still rides the a-03 installable ledger (KA-22 GREEN)")
              (require (a3PkgNames == [ "mcp-scan" "mcp-guardian" "mcp-remote" "agentdojo" ])
                "a-03-options: the a-03 install set drifted from the landed overlay set at a3cf74e (mcp-scan, mcp-guardian, mcp-remote, agentdojo — pk#55 merged; the KA-24 d-01 all-pending posture ended with the packaging merge)")
              (require (!(lib.elem "mcp-unsafe-deser-probe" a3PkgNames) && !(lib.elem "mcpoison" a3PkgNames))
                "a-03-options: a safety:exp row reached the a-03 package list — the §11.2 gate owns that surface (KA-22)")
              (require (!(lib.elem "poisoned-skill-pack" (a3Ledger.installable ++ a3Ledger.exp)))
                "a-03-options: the data row poisoned-skill-pack leaked into the a-03 installable/exp ledgers (D7)")
              (require (lib.elem "poisoned-skill-pack" (map (e: e.id) a3Ledger.excluded))
                "a-03-options: the data row poisoned-skill-pack left the ledger's excluded set (D7)")
            ];
          in
          pkgs.runCommand "a-03-options"
            {
              proofs = toString _evalProofs;
            }
            ''
              echo "a-03 install set (pnames): ${toString a3PkgNames}"
              echo "a-03 exp ledger (lab-mode-gated, never installed): ${toString a3Ledger.exp}"
              echo "a-03-options: ${toString (lib.length _evalProofs)} eval proofs passed [${toString _evalProofs}]"
              touch $out
            '';

        a-04-options =
          let
            a4Host = (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [ { kailash.layers.attack.categories.a-04.enable = true; } ];
            });
            a4PkgNames =
              map (p: p.pname or (builtins.parseDrvName p.name).name)
                a4Host.config.kailash.layers.attack.categories.a-04.packages;
            a4Ledger = (builtins.fromJSON (builtins.readFile ./generated/manifest-ids.json))
              .categories.a-04-model-supply-chain;
            require = cond: msg: if cond then true else throw msg;
            _evalProofs = [
              (require (a4Ledger.exp == [ "torch-load-poc" ])
                "a-04-options: the generator's exp ledger does not record exactly [torch-load-poc] (KA-22 GREEN)")
              (require (!(lib.elem "torch-load-poc" a4Ledger.installable))
                "a-04-options: the exp row torch-load-poc still rides the a-04 installable ledger (KA-22 GREEN)")
              (require (a4PkgNames != [ ])
                "a-04-options: install set EMPTY — the a-04 category module has not landed (KA-22 GREEN)")
              (require (!(lib.elem "torch-load-poc" a4PkgNames))
                "a-04-options: a safety:exp row reached the a-04 package list — the §11.2 gate owns that surface (KA-22)")
              (require (lib.elem "modelscan" a4PkgNames)
                "a-04-options: the a-04 category module did not bind the NATIVE modelscan row (KA-22 GREEN)")
            ];
          in
          pkgs.runCommand "a-04-options"
            {
              proofs = toString _evalProofs;
            }
            ''
              echo "a-04 install set (pnames): ${toString a4PkgNames}"
              echo "a-04 exp ledger (lab-mode-gated, never installed): ${toString a4Ledger.exp}"
              echo "a-04-options: ${toString (lib.length _evalProofs)} eval proofs passed [${toString _evalProofs}]"
              touch $out
            '';
        # ---- The §8.1 image-matrix eval legs (KA-28, ko#28) ----------------
        #
        # images-census: the eval-side census gate, REQUIRE/THROW at EVAL
        # time (the runCommand renders only after both assertions hold —
        # a drift never reaches the build phase). Re-derives the walker's
        # per-target closure-name count (images/closure-walk.nix over
        # images/generator.nix's per-profile toplevels) and requires it
        # EQUAL to the committed snapshot (tests/images-census.json) — a
        # manifest merge or a pin bump that moves the closures throws at
        # eval until scripts/gen-image-census.sh regenerates the snapshot
        # in the same cycle. Also requires the §8.1 exclusions per target:
        # the heavy tokens (seclists / gnuradio / gqrx / hackrf / sox /
        # librosa / texlive) and the opt-in pack rows (kailash-data.*,
        # sdr-tools, wordlists-mega) must NEVER appear in a default image
        # closure — the packs are forced opt-in by construction, proven at
        # eval per target per format.
        images-census =
          let
            gen = import ./images/generator.nix {
              inherit lib;
              pkgsLinux = pkgs;
              nixos-generators = inputs.nixos-generators;
            };
            walk = import ./images/closure-walk.nix { inherit lib; };
            snapshot = builtins.fromJSON (builtins.readFile ./tests/images-census.json);
              countsByName = builtins.mapAttrs (_: tl: (walk tl).count) gen.toplevels;
            packTokenRe = "seclists|gnuradio|gqrx|hackrf|sox|librosa|texlive|kailash-data|sdr-tools|wordlists";
            heavyTokens = name:
              lib.filter
                (n: builtins.match ".*(${packTokenRe}).*" n != null)
                (walk (builtins.getAttr name gen.toplevels)).names;
            # The eval-time proof: per target, snapshot==live AND zero
            # heavy tokens. One lib.require-style assertion chain — the
            # first violated target throws with its name + both counts.
            proveTarget = name: cnt:
              if snapshot.targets ? ${name} then
                assert (snapshot.targets.${name}.count or (-1) == cnt
                  || throw "images-census: ${name} drift — snapshot ${toString (snapshot.targets.${name}.count or (-1))} != live ${toString cnt} (regenerate via scripts/gen-image-census.sh)");
                assert (builtins.length (heavyTokens name) == 0
                  || throw "images-census: ${name} carries ${toString (builtins.length (heavyTokens name))} excluded heavy tokens — the packs must stay opt-in");
                "${name}=${toString cnt}"
              else
                throw "images-census: target ${name} missing from the committed snapshot (tests/images-census.json)";
            proofs = lib.mapAttrsToList proveTarget countsByName;
          in
          assert (lib.length proofs == 8
            || throw "images-census: expected 8 §8.1 targets, live walker produced ${toString (lib.length proofs)}");
          pkgs.runCommand "images-census"
            { } ''
            # The eval-side assertions above ran BEFORE this derivation
            # rendered; this body prints the proofs verbatim and succeeds.
            cat <<EOPROOFS
            ${lib.concatStringsSep "\n" proofs}
            EOPROOFS
            echo "images-census: 8/8 targets snapshot-equal, heavy exclusions clean (eval-proven)"
            touch $out
          '';

        # images-budget-selftest: the §8.1 verifier's own proof — the
        # breach + PACK-LEAK + clean cases driven through the SAME
        # enforcement unit the release-lane mass legs call (the mass
        # legs run the verifier against closureInfo-produced census
        # documents; the committed snapshot carries only the count
        # census, so the enforce path is exercised on synthetic
        # closure data here). The watched RED shape: a stub verifier
        # leaves all three cases unproven and the leg fails loudly.
        images-budget-selftest = pkgs.runCommand "images-budget-selftest"
          {
            nativeBuildInputs = [ pkgs.python3 ];
          } ''
          ${pkgs.python3}/bin/python3 ${./tools/kailash-images-budget.py} --self-test > self-test.out
          grep -q "OK (breach + exclusion + clean all proven)" self-test.out \
            || { echo "images-budget-selftest: the verifier did not prove breach+exclusion+clean:"; cat self-test.out; exit 1; }
          echo "images-budget-selftest: OK — breach+pack-leak+clean proven through the enforcement unit"
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

      # The C-3 composition host (KA-07.1, ko#99): the CORE floor with C-3
      # Web Application Assessment enabled. RED stub: the c-03 module
      # installs nothing yet (the binding-table wiring lands GREEN), so
      # the host carries an EMPTY c-03 install set and the c-03-options
      # check's non-empty + flagship assertions are the watched red.
      nixosConfigurations.kailash-c-03-composition = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          { kailash.layers.classic.categories.c-03.enable = true; }
        ];
      };


      nixosConfigurations.kailash-c-10-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          { kailash.layers.classic.categories.c-10.enable = true; }
        ];
      };

      # The A-2 data-pack composition fixture (KA-13.2, ko#104): the CORE
      # floor with the a-02 category AND the sibling `packs` composition
      # option ON. NOT a product profile; eval-gated by the
      # a-02-data-packs-compose check (packs ride the typed a-02 surface
      # from the overlay; the KA-13.1 A-2 category module owns install
      # wiring when it lands). The floor host (kailash-minimal) proves
      # the defaults-false + no-leakage halves of the same leg.
      nixosConfigurations.kailash-a-02-packs = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            kailash.layers.attack.categories.a-02.enable = true;
            kailash.layers.attack.categories.a-02.packs = true;
          }
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

      # The VM smoke suite's boot host (KA-06.3, ko#98): the full
      # profile + qemu-vm.nix (the `nixos-rebuild build-vm` module —
      # provides the virtualisation.* options and the build.vm runner;
      # its fileSystems mkVMoverride supersedes minimal.nix's
      # placeholder root inside the VM) with the runner tunables the
      # tests/vm-smoke-*.nix legs mirror in their nodes. Eval-side this
      # host is checked by the classic-vm-smoke-contract leg; the BOOT
      # runs on a Linux VM host per tests/README.md.
      nixosConfigurations.kailash-vm-full = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/full.nix
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          {
            virtualisation.graphics = false;
            virtualisation.cores = 2;
            virtualisation.memorySize = 4096;
          }
        ];
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

      # The §4.5 category-install fixtures for the KA-07.3 pair (ko#101):
      # synthetic hosts with the C-8 / C-9 category ENABLED — the
      # c-08-options / c-09-options legs ride them. NOT product profiles.
      nixosConfigurations.kailash-c-08-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-c-08-enabled";
            kailash.layers.classic.categories.c-08.enable = true;
          }
        ];
      };

      nixosConfigurations.kailash-c-09-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-c-09-enabled";
            kailash.layers.classic.categories.c-09.enable = true;
          }
        ];
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

      # The GVM SERVICE composed (KA-27, ko#27): a synthetic host with
      # services.kailash.gvm ENABLED — EVAL-ONLY (no check leg, no CI
      # build): nix flake check evaluates every nixosConfiguration, so
      # this host proves the service module composes and produces the
      # unit tree without building its closure (the same eval-only
      # posture the kailash-mlflow-enabled fixture owns — NOT a product
      # profile).
      nixosConfigurations.kailash-gvm-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-gvm-enabled";
            services.kailash.gvm.enable = true;
            # The eval-only fixture supplies the manager stand-in (the
            # gvmd derivation is ABSENT from the pin — the package
            # CONTRACT requires the operator to supply it; the unit
            # composition, not the manager's runtime, is what this
            # fixture proves).
            services.kailash.gvm.package = pkgs.stdenv.mkDerivation {
              name = "gvm-manager-standin";
              unpackPhase = "true";
              installPhase = "mkdir -p $out/bin; printf '#!/bin/sh\necho gvmd-standin\n' > $out/bin/gvmd; chmod +x $out/bin/gvmd";
            };
          }
        ];
      };

      # The platform profile host (KA-08.5, kailash-os#109): the CORE
      # floor + O-1 (services.kailash.mlflow :5000) + O-4 (ollama
      # :11434) — the acceptance VM's composition, pinned by the
      # o-05-platform-services leg through the SAME eval. NOT a product
      # profile: images for the surface are Wave-6 items (KA-28.0
      # QEMU-primary); the acceptance run exercises THIS toplevel.
      nixosConfigurations.kailash-platform = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [ ./profiles/platform.nix ];
      };

      # The platform ACCEPTANCE-VM fixture (KA-08.5, kailash-os#109): the
      # platform host with the DOCUMENTED lab posture the acceptance boot
      # runs under — ollama binds 0.0.0.0 (the o-04 docs' operator move;
      # the qemu user-net VM is an isolated lab segment), the tiny model
      # rides services.ollama.loadModels (the documented operator step,
      # carried explicitly so the boot performs the pull), MLflow's
      # labReachable (the module's documented 0.0.0.0 lab bind). Pinned
      # at eval by the o-05-platform-acceptance leg. NOT a product
      # profile.
      nixosConfigurations.kailash-platform-acceptance = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/platform.nix
          {
            services.ollama.host = "0.0.0.0";
            services.ollama.loadModels = [ "qwen2.5:0.5b" ];
            services.kailash.mlflow.labReachable = true;
          }
        ];
      };

      # §4.5 category-install fixtures (KA-13.1, ko#103): synthetic hosts
      # with an ATTACK category ENABLED — prove "enabling a test host
      # installs without breaking eval" for A-1 and A-2 (the same not-a-
      # product-profile pattern the kailash-o-01-enabled fixture owns).
      nixosConfigurations.kailash-a-01-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-a-01-enabled";
            kailash.layers.attack.categories.a-01.enable = true;
          }
        ];
      };

      nixosConfigurations.kailash-a-02-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-a-02-enabled";
            kailash.layers.attack.categories.a-02.enable = true;
          }
        ];
      };

      # §4.5 DEFENCE category-install fixtures (KA-24, os#24): synthetic
      # hosts with DEFENCE categories ENABLED — prove "enabling a test
      # host installs without breaking eval" for the two categories whose
      # install surfaces bind at the pin (d-03, d-04) and the
      # all-categories MERGE (d-01…d-07 ON simultaneously — the seven
      # config-only mounts compose through the same spine). The same
      # not-a-product-profile pattern the kailash-a-01-enabled fixture
      # owns; never product profiles.
      nixosConfigurations.kailash-d-03-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-d-03-enabled";
            kailash.layers.defence.categories.d-03.enable = true;
          }
        ];
      };

      # §4.5 category-install fixtures (KA-22, ko#22): synthetic hosts with
      # an ATTACK long-tail category ENABLED — the same not-a-product-
      # profile pattern the kailash-a-01/02-enabled fixtures own (the A-3
      # host carries exp-class manifest rows: the §11.2 routing keeps them
      # OFF the package list entirely — the check leg rides the eval
      # tripwire below; no labMode flip is involved in the fixture).
      nixosConfigurations.kailash-a-03-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-a-03-enabled";
            kailash.layers.attack.categories.a-03.enable = true;
          }
        ];
      };

      nixosConfigurations.kailash-d-04-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-d-04-enabled";
            kailash.layers.defence.categories.d-04.enable = true;
          }
        ];
      };

      nixosConfigurations.kailash-defence-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-defence-enabled";
            kailash.layers.defence.categories = lib.genAttrs
              [ "d-01" "d-02" "d-03" "d-04" "d-05" "d-06" "d-07" ]
              (_: { enable = true; });
          }
        ];
      };

      nixosConfigurations.kailash-a-04-enabled = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          ./profiles/minimal.nix
          {
            networking.hostName = lib.mkForce "kailash-a-04-enabled";
            kailash.layers.attack.categories.a-04.enable = true;
          }
        ];
      };

      # devShells per category with KA-09; images with the images wave;
      # devShells per category landed with KA-09.4 (ko#113); the images wave
      # lands here.

      # ---- The §8.1 image matrix + size budgets (KA-28, ko#28) ------------
      #
      # One GENERATOR (images/generator.nix): each shipped profile evals once
      # through nixos-generators' format module and splits into the TWO shapes
      # the ratified deliverable-shape decision (ko#132) ships — the QEMU qcow2
      # (PRIMARY, drives KA-32's golden-image gate + KA-43's boot polish) and
      # the bootable ISO (SECONDARY, bare-metal evaluation). The budget table
      # (images/kailash-images-table.nix) carries the plan §8.1 budgets, the
      # committed census snapshot (tests/images-census.json) the
      # derivation-level closure evidence, scripts/gen-image-census.sh the
      # regeneration cycle, tools/kailash-images-budget.py the verifier.
      #
      # Exposure: the artifact derivations as `packages` (`nix build
      # .#kailash-images-qemu-minimal`), the census/verifier as flake `apps`
      # (`nix run .#images-census`), and the check legs the eval gate runs:
      #   * images-census — the walker's per-target closure-name count
      #     asserts equal to the committed snapshot; heavy-pack tokens
      #     (seclists / gnuradio / gqrx / hackrf / texlive / the
      #     kailash-data.* opt-in packs) assert ABSENT — the exclusion by
      #     construction is eval-proven here, per target.
      #   * images-budget-selftest — the verifier's breach + pack-leak +
      #     clean cases (the watched-RED shape: a stub verifier trips all
      #     three).
      # The MASS budget legs (closureInfo NarSize sums) are RUNTIME legs
      # invoked from CI/the release lane against the hosted toplevels —
      # not flake-check attrs (they would build the whole images closure
      # on every PR).
      packages.${system} =
        let
          gen = import ./images/generator.nix {
            inherit lib;
            pkgsLinux = pkgs;
            nixos-generators = inputs.nixos-generators;
          };
        in
        # The §8.1 image artifacts, FLATTENED into packages (each target's
        # ref = `kailash-images-<format>-<profile>` — the table carries the
        # refs; `nix build .#<ref>` per target). NOTE: each ref key here
        # resolves to ONE derivation (the image artifact); the toplevels
        # (gen.toplevels) stay internal to the census/budget legs — nothing
        # double-keys packages (a nested attrset here is not a derivation
        # and flake check rejects it).
        lib.mapAttrs' (name: target: lib.nameValuePair target.ref gen.images.${name})
          (import ./images/kailash-images-table.nix).targets;

      apps.${system} = {
        images-census = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "kailash-images-census-runner";
            runtimeInputs = [ pkgs.python3 ];
            text = ''
              exec bash ${./scripts/gen-image-census.sh} "$@"
            '';
          }}";
        };
      };

      # ---- per-category devShells (KA-09.4, ko#113): `nix develop .#<category>` ---
      #
      # ONE shell per SHIPPED category (a category with an install-set
      # module on master): the category's INSTALL SET as the shell
      # packages — read through the §4.5 typed spine itself (extendModules
      # of the CORE minimal floor with the category enable, then the
      # category's own `packages` option, never the host's whole
      # systemPackages — the shell carries the category, mkShell adds the
      # standard toolchain). Generated over the shipped map (mapAttrs),
      # new shipped categories join the map (o-04 with KA-09.3's module,
      # o-05/o-07 with their wave items). Every id and its package set is
      # additionally asserted by the checks.category-devshells leg.
      devShells.${system} = builtins.mapAttrs
        (id: layer: pkgs.mkShell {
          name = "kailash-${id}-devshell";
          packages =
            (self.nixosConfigurations.kailash-minimal.extendModules {
              modules = [ { kailash.layers.${layer}.categories.${id}.enable = true; } ];
            }).config.kailash.layers.${layer}.categories.${id}.packages;
        })
        {
          c-01 = "classic";
          c-02 = "classic";
          c-04 = "classic";
          c-06 = "classic";
          o-01 = "ops";
          o-02 = "ops";
          o-03 = "ops";
          o-05 = "ops";
          o-06 = "ops";
          # DEFENCE joins with KA-24 (os#24): the categories with
          # install sets that BIND at the pin — d-03 (evaluate +
          # lm-eval via python3Packages) and d-04 (cosign/syft/grype/
          # trivy/cyclonedx-cli/cdxgen bare + model-signing via
          # python3Packages.model-signing). The empty-surface
          # categories (d-01, d-02, d-05, d-06, d-07 — every installable
          # row overlay-pending at this pin) ship NO shell yet: a shell
          # of zero packages is the lie the shipped map refuses.
          d-03 = "defence";
          d-04 = "defence";
        };

      # devShells with KA-09 (landed: KA-09.4); images with the images wave
      # (KA-28, this splice); remaining hosts (kailash-full etc.) land with
      # their profile items.

      # ---- VM smoke suite (KA-06.3, ko#98): tests/c-01.nix etc -------------
      #
      # NOTE intentionally NOT `checks`: `nix flake check` builds-and-runs
      # check attrs, and its runners (hosted, KA-08.4 posture; this lane
      # box) cannot boot x86_64-linux VMs — a checks-registered nixosTest
      # would red every flake-check run. The legs live here as the
      # EXECUTABLE suite; `nix flake check`'s option-tree sweep (every
      # nixosConfiguration in the flake is eval-checked) exercises their
      # eval, and a Linux VM host runs them per tests/README.md:
      #   nix build -L .#vmTests.x86_64-linux.<leg>
      # The eval-side contract check (checks.classic-vm-smoke-contract)
      # binds THIS suite to the module options (the watched-RED leg —
      # without it the unregistered tests could drift silently from the
      # modules and modules could drift from the manifest unprobed).
      vmTests.${system} = {
        c-01 = import ./tests/c-01.nix {
          inherit lib pkgs system;
          installSurface = self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-01.packages;
        };
        c-02 = import ./tests/c-02.nix {
          inherit lib pkgs system;
          installSurface = self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-02.packages;
        };
        c-04 = import ./tests/c-04.nix {
          inherit lib pkgs system;
          installSurface = self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-04.packages;
        };
        c-06 = import ./tests/c-06.nix {
          inherit lib pkgs system;
          installSurface = self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.c-06.packages;
        };
        full-profile-boot = import ./tests/full-profile-boot.nix {
          inherit lib pkgs system;
          installSurface = builtins.mapAttrs
            (id: _: self.nixosConfigurations.kailash-full.config.kailash.layers.classic.categories.${id}.packages)
            { c-01 = null; c-02 = null; c-04 = null; c-06 = null; };
        };
      };
    };
}
