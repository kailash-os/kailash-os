# VM smoke harness helpers (KA-06.3, ko#98; plan §9 Phase 2).
#
# Shared machinery for tests/c-01.nix, tests/c-04.nix, tests/c-02.nix,
# tests/c-06.nix and tests/full-profile-boot.nix — the booted-VM
# acceptance legs for the four Wave-5 CLASSIC category modules.
#
# VM reality (issue #98): hosted CI runners cannot boot VMs (no KVM)
# and the lane box cannot build x86_64-linux derivations, so the legs
# live under the flake's `vmTests` namespace (evaluated by `nix flake
# check`'s option-tree sweep, never built by it) and RUN on a Linux VM
# host per tests/README.md, e.g.  nix build -L .#vmTests.x86_64-linux.c-01
{
  lib,
  pkgs,
  system,
  categoryName,
  title,
  categories,
  installSurface,
  pathNames,
  binAliases ? { },
  helpExceptions ? { },
  flagshipCmds,
}:
let
  dataJson = lib.generators.toJSON { } {
    inherit categories;
    surface = lib.listToAttrs (
      map (cat: {
        name = cat;
        value = map (
          p: {
            out = toString p;
            pname = p.pname or (builtins.parseDrvName p.name).name;
          }
        ) installSurface.${cat};
      }) categories
    );
    pathNames = pathNames;
    binAliases = binAliases;
    exceptions = helpExceptions;
    flagships = flagshipCmds;
  };
  dataFile = pkgs.writeText "vm-smoke-${categoryName}-data.json" dataJson;

  testScript = ''
    import json

    with open("${dataFile}") as f:
        data = json.load(f)
    cats = data["categories"]
    surface = data["surface"]
    path_names = data["pathNames"]
    bin_aliases = data["binAliases"]
    exceptions = data["exceptions"]
    flagships = data["flagships"]

    machine.wait_for_unit("multi-user.target")

    hostname = machine.succeed("hostname").strip()
    assert hostname == "kailash-full", (
        f"VM hostname is not kailash-full: got {hostname!r} "
        "(the full profile did not drive the boot)"
    )

    for cat in cats:
        rows = surface[cat]
        machine.log(f"{cat}: {len(rows)} installed rows")
        # (1) the REAL system closure carries every row's store path —
        # the category actually installed; a wrapper named after a tool
        # cannot fake the store paths.
        for row in rows:
            probe = machine.succeed(
                f"test -d '{row['out']}' && echo in || echo out"
            ).strip()
            assert probe == "in", (
                f"{cat}: store path {row['out']} ({row['pname']}) is NOT in the VM closure"
            )

        # (2) the manifest PATH-name rows resolve inside the rows'
        # bin|sbin dirs. Matching is case-insensitive (manifest ids are
        # the PATH names; some package binaries differ in case, e.g.
        # theHarvester). Documented name mismatches take binAliases
        # (the same review standard as the modules' binding tables).
        resolved = []
        unresolved = []
        for want in path_names[cat]:
            binname = bin_aliases.get(cat, {}).get(want, want)
            hit = None
            for row in rows:
                for sub in ("bin", "sbin"):
                    listing = machine.succeed(
                        f"ls '{row['out']}/{sub}' 2>/dev/null || true"
                    )
                    for cand in listing.split():
                        if cand.lower() == binname.lower():
                            hit = f"{row['out']}/{sub}/{cand}"
                            break
                    if hit:
                        break
                if hit:
                    break
            if hit is None:
                reason = exceptions.get(cat, {}).get(want)
                if reason is not None:
                    machine.log(f"{cat}: '{want}' unresolved (skipped: {reason})")
                else:
                    unresolved.append(want)
            else:
                resolved.append((want, hit))
        if unresolved:
            raise AssertionError(
                f"{cat}: manifest PATH rows resolve to no command in "
                f"{len(rows)} installed rows: {', '.join(unresolved)} "
                "(binding table or bin layout drifted — RED the contract leg)"
            )
        machine.log(
            f"{cat}: {len(resolved)}/{len(path_names[cat])} PATH rows resolved"
        )

        # (3) flagship anchors, by name.
        for flag in flagships[cat]:
            present = any(w == flag for w, _ in resolved)
            assert present, (
                f"{cat}: flagship '{flag}' absent from the resolved PATH surface"
            )
        if flagships[cat]:
            machine.log(
                f"{cat}: flagship anchors resolved: {', '.join(flagships[cat])}"
            )

        # (4) the --help sweep: every resolved command must exit 0 on
        # `--help` (ko#98's acceptance, per command). Skips only via the
        # helpExceptions table (explicit, reviewable rows: GUI
        # launchers / non-uniform help flags).
        failures = []
        for want, cmd in resolved:
            if exceptions.get(cat, {}).get(want) is not None:
                machine.log(f"{cat}: --help skipped for '{want}' (exceptions row)")
                continue
            _st, out = machine.execute(
                f"timeout 120 '{cmd}' --help </dev/null >/dev/null 2>&1; echo rc=$?"
            )
            rc = -1
            for token in out.split():
                if token.startswith("rc="):
                    rc = int(token[3:])
            if rc != 0:
                failures.append(f"'{want}' ({cmd}) rc={rc}")
            machine.log(f"{cat}: {want} --help rc={rc}")

        if failures:
            machine.log(f"{cat}: --help FAILURES: " + "; ".join(failures))
            raise AssertionError(
                f"{cat}: {len(failures)} of {len(resolved)} commands failed the "
                "--help sweep: " + "; ".join(failures)
            )
        machine.log(f"{cat}: vm-smoke sweep OK ({len(resolved)} commands probed)")

    machine.log("VM smoke sweep complete: all categories green")
  '';
in
pkgs.testers.nixosTest {
  name = title;
  inherit testScript;
  skipTypeCheck = true;
  nodes.machine =
    { ... }:
    {
      imports = [ ../profiles/full.nix ];
      networking.hostName = lib.mkForce "kailash-full";
      virtualisation.graphics = false;
      virtualisation.cores = 2;
      virtualisation.memorySize = 4096;
      virtualisation.diskSize = 16384;
    };
}
