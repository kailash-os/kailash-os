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

      # Layer-ATTACK red-team profile (KA-17.1, os#114): CORE floor + Layer
      # ATTACK full + O-4 (local inference labs). Evaluates through the
      # module tree with the flat option spine until the Wave-5
      # per-category wiring lands (see the profile header note).
      nixosConfigurations.kailash-redteam-ai = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [ ./profiles/redteam-ai.nix ];
      };

      # devShells per category with KA-09; images with the images wave;
      # remaining hosts (kailash-full etc.) land with their profile items.
    };
}
