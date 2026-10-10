#!/usr/bin/env python3
# tools/manifest-matrix.py — the manifest→matrix generator (KA-15.1 #88).
#
# MIRROR PAIR: this generator is vendored byte-identically in BOTH repos —
# kailash-os/tools/manifest-matrix.py and
# kailash-packages/tools/manifest-matrix.py. Keep the two byte-identical
# (diff in verify); a change lands against both in the same cycle.
#
# Source of truth resolution, deterministically:
#   * OS-mode (default): the flake.lock `kailash-packages` node rev is read
#     from the committed lock and that rev's tarball is fetched from the
#     GitHub codeload URL pinned to the rev — no floating heads. The lock
#     records narHash for the pin, so the fetch is reproducible.
#   * repo-mode (--manifest-dir <dir>): reads tools.yaml directly from the
#     given manifest dir (packages repo, or any local tree).
#
# Core = pure function from manifest dict to GitHub Actions matrix JSON
# (`include` entries each carrying `package` and `system`, over
# x86_64-linux and aarch64-linux). Fallback: a header-only manifest (empty
# tools list) yields the pkgs/ auto-call directories — during the census
# fill (KA-05) the matrix follows the real pkgs/ build surface instead of
# emitting an empty matrix that silently skips CI (watched RED: the
# manifest-only source emitted `{"include": []}`; GREEN falls back to the
# pkgs/ auto-call dirs).
#
# Python stdlib-first: PyYAML is used when importable; a stdlib fallback
# parser covers the manifest's own header-only shape (flat scalars plus
# `tools: []`) without any dependency.
#
# Self-test: python3 tools/manifest-matrix.py --self-test (assert-based).

from __future__ import annotations

import json
import os
import sys
from urllib.request import Request, urlopen

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SYSTEMS = ("x86_64-linux", "aarch64-linux")

# The packages repo the OS flake pins (flake.lock node name must match).
REPO = "kailash-os/kailash-packages"

DEFAULT_PKGS_DIR = "pkgs"


def _load_yaml(text):
    """Parse YAML with PyYAML when importable, else the stdlib fallback.

    Returns (doc, mode). The fallback covers the manifest's own
    header-only shape (flat scalars and a possibly empty top-level scalar
    list) and fails loudly — never silently mis-parses — on richer shapes.
    """
    try:
        import yaml  # type: ignore[import-not-found]
    except ImportError:
        pass
    else:
        return yaml.safe_load(text), "pyyaml"
    return _load_yaml_fallback(text), "stdlib-fallback"


def _load_yaml_fallback(text):
    """Minimal stdlib YAML fallback: flat scalar keys plus `key: []`.

    Refuses anything it cannot parse unambiguously (structured list
    entries, nested mappings, tab indentation) so a richer manifest fails
    loudly instead of silently mis-parsing.
    """
    if "\t" in text:
        raise ValueError("stdlib yaml fallback: tab indentation not supported")
    doc = {}
    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if line.strip() == "---":
            continue
        stripped = line.strip()
        if stripped.startswith("- "):
            raise ValueError(
                "stdlib yaml fallback: structured list entries need pyyaml: "
                f"{line!r}"
            )
        if ":" not in stripped:
            raise ValueError(f"stdlib yaml fallback: unparsable line: {line!r}")
        key, _, value = stripped.partition(":")
        key = key.strip()
        value = value.strip()
        if value == "[]":
            doc[key] = []
        elif value == "":
            raise ValueError(
                f"stdlib yaml fallback: empty value for {key!r} needs pyyaml"
            )
        else:
            doc[key] = value.strip("'\"")
    return doc


def _pkgs_fallback_names(pkg_repo_dir):
    """pkgs/ auto-call dirs (sorted): the fallback build surface.

    Reads the auto-call surface the packages flake builds from: every
    pkgs/<dir>/default.nix, excluding `.nocall` directories — the same
    surface `pkgs/auto-call.nix` filters for (KA-02.3). GREEN half of the
    watched RED: with this wired, a header-only manifest yields the
    auto-call dirs (subfinder, dnsrecon today) instead of an empty matrix.
    """
    pkgs_dir = os.path.join(pkg_repo_dir, DEFAULT_PKGS_DIR)
    if not os.path.isdir(pkgs_dir):
        return []
    names = []
    for name in sorted(os.listdir(pkgs_dir)):
        tool_dir = os.path.join(pkgs_dir, name)
        if (
            os.path.isdir(tool_dir)
            and os.path.isfile(os.path.join(tool_dir, "default.nix"))
            and not os.path.isfile(os.path.join(tool_dir, ".nocall"))
        ):
            names.append(name)
    return names


def matrix_entries_from_tool_rows(tools):
    """§5.2 tool rows → sortable overlay package names (os#135 contract).

    Matrix entries are the overlay's buildable surface: bespoke rows
    contribute their `packaging.derivation` dir (`pkgs/<dir>/default.nix`
    → `<dir>`, single segment only); native rows are nixpkgs-provided
    and never overlay buildables. Plain-string rows (the fixture-era
    shape) pass through unchanged. Rows without a usable derivation
    contribute nothing — callers existence-gate the result against the
    pkgs/ auto-call dirs so the matrix never carries a phantom leg.
    """
    names = set()
    for t in tools:
        if isinstance(t, str):
            names.add(t)
            continue
        if not isinstance(t, dict):
            continue
        packaging = t.get("packaging") or {}
        if packaging.get("status") != "bespoke":
            continue
        drv = packaging.get("derivation")
        if (
            isinstance(drv, str)
            and drv.startswith("pkgs/")
            and drv.endswith("/default.nix")
        ):
            name = drv[len("pkgs/") : -len("/default.nix")]
            if name and "/" not in name:
                names.add(name)
    return sorted(names)


def manifest_dict_to_matrix(manifest, pkgs_names=None):
    """Pure core: manifest dict → GitHub Actions matrix dict.

    A filled tools table maps entries over both systems — via
    `matrix_entries_from_tool_rows` (bespoke derivations; os#135
    contract). A header-only manifest (empty tools list) falls back to
    the pkgs/ auto-call dir names when the caller supplies
    `pkgs_names` (the CLI resolver supplies them; the pure function
    stays pure). When the fallback is unavailable (`pkgs_names=None`)
    or empty (no pkgs dirs), the matrix is empty — never invented rows.
    Deterministic: sorted names, fixed SYSTEMS order.
    """
    tools = manifest.get("tools") or []
    names = matrix_entries_from_tool_rows(tools)
    if not names and pkgs_names:
        names = sorted(str(n) for n in pkgs_names)
    include = [
        {"package": name, "system": system}
        for name in names
        for system in SYSTEMS
    ]
    return {"include": include}


def matrix_json_for_names(names) -> str:
    """Resolved package names → matrix JSON (sorted, deterministic)."""
    include = [
        {"package": name, "system": system}
        for name in sorted(str(n) for n in names)
        for system in SYSTEMS
    ]
    return json.dumps({"include": include}, sort_keys=True)


def matrix_json(manifest, pkgs_names=None) -> str:
    """Manifest dict → the matrix JSON string (key-sorted, deterministic)."""
    return json.dumps(manifest_dict_to_matrix(manifest, pkgs_names), sort_keys=True)


# --- pinned-source resolution (OS-mode) --------------------------------


def packages_rev_from_flake_lock(lock_path):
    """Read the `kailash-packages` input node's locked rev from flake.lock."""
    with open(lock_path, encoding="utf-8") as fh:
        lock = json.load(fh)
    node = lock.get("nodes", {}).get("kailash-packages")
    if not node:
        raise ValueError(f"No 'kailash-packages' node in {lock_path}")
    locked = node.get("locked") or {}
    if locked.get("type") != "github" or "rev" not in locked:
        raise ValueError(
            f"kailash-packages node is not a pinned github rev: {locked!r}"
        )
    return locked["rev"]


def _codeload_url(repo, rev):
    """The codeload tarball URL pinned to an exact rev (no floating heads)."""
    if not rev or not rev.strip():
        raise ValueError("rev required (no floating heads)")
    return f"https://codeload.github.com/{repo}/tar.gz/{rev}"


def _http_get(url):
    req = Request(url, headers={"User-Agent": "kailash-manifest-matrix/1.0"})
    with urlopen(req, timeout=60) as resp:  # nosec — pinned rev URLs only
        if resp.status != 200:
            raise RuntimeError(f"GET {url} -> HTTP {resp.status}")
        return resp.read()


def manifest_and_pkgs_names_from_tarball(blob):
    """Extract (manifest_dict, pkgs_names) from the pinned rev tarball."""
    import io
    import tarfile

    tf = tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz")
    manifest_doc = None
    pkgs_names = set()
    pkgs_prefix_seen = False
    for member in tf.getmembers():
        parts = member.name.split("/", 1)
        if len(parts) != 2:
            continue
        rel = parts[1]
        if rel == os.path.join("manifest", "tools.yaml"):
            fh = tf.extractfile(member)
            if fh is not None:
                manifest_doc, _mode = _load_yaml(fh.read().decode("utf-8"))
        elif rel.startswith(DEFAULT_PKGS_DIR + "/"):
            pkgs_prefix_seen = True
            tail = rel[len(DEFAULT_PKGS_DIR) + 1 :]
            if tail.endswith("/default.nix"):
                name = tail[: -len("/default.nix")]
                if "/" not in name:
                    pkgs_names.add(name)
    if manifest_doc is None:
        raise RuntimeError("manifest/tools.yaml not found in the pinned tarball")
    if not pkgs_prefix_seen:
        pkgs_names = set()  # no pkgs/ dir in the pin: fallback stays empty
    return manifest_doc, sorted(pkgs_names)


def matrix_names_for_build(manifest, auto_names):
    """Manifest → the overlay's buildable package names, existence-gated.

    `matrix_entries_from_tool_rows` derives the manifest's bespoke surface;
    gating it against `auto_names` (the pkgs/ auto-call dirs at the same
    tree state) keeps the matrix phantom-free while the KA-05/KA-05.x
    waves land rows ahead of their Wave-5/6 derivations. A header-only
    manifest falls back to the auto-call dirs (unchanged KA-15.1
    contract); so does a filled manifest whose bespoke derivations are
    not on disk yet — the overlay's real surface is what builds.
    """
    names = matrix_entries_from_tool_rows(manifest.get("tools") or [])
    auto = sorted(str(n) for n in (auto_names or []))
    if not names:
        return auto
    gated = [n for n in names if n in set(auto)]
    if gated:
        return gated
    return auto


def build_matrix_from_lock(lock_path, repo=REPO):
    """OS-mode: pinned rev from the committed flake.lock → matrix JSON."""
    rev = packages_rev_from_flake_lock(lock_path)
    blob = _http_get(_codeload_url(repo, rev))
    manifest, pkgs_names = manifest_and_pkgs_names_from_tarball(blob)
    return matrix_json_for_names(matrix_names_for_build(manifest, pkgs_names))


def build_matrix_from_manifest_dir(manifest_dir, fallback_repo_dir=None):
    """Repo-mode: tools.yaml from the given manifest dir → matrix JSON.

    `fallback_repo_dir` names the packages repo root the manifest dir
    lives in, for the pkgs/ fallback; when None the manifest-dir's parent
    is used. The matrix is existence-gated against the pkgs/ auto-call
    dirs at the same tree state (os#135) — bespoke rows ahead of their
    derivations fall back to the real overlay surface.
    """
    tools_yaml = os.path.join(manifest_dir, "tools.yaml")
    with open(tools_yaml, encoding="utf-8") as fh:
        manifest, _mode = _load_yaml(fh.read())
    repo_dir = fallback_repo_dir or os.path.dirname(manifest_dir)
    return matrix_json_for_names(
        matrix_names_for_build(manifest, _pkgs_fallback_names(repo_dir))
    )


def emit(lock_path=None, manifest_dir=None, repo=REPO, out=None):
    """CLI entry: emit the matrix JSON for the resolved source mode."""
    if out is None:
        out = sys.stdout
    if manifest_dir:
        json_text = build_matrix_from_manifest_dir(manifest_dir)
    else:
        json_text = build_matrix_from_lock(lock_path, repo=repo)
    out.write(json_text + "\n")


def self_test() -> None:
    """Assert-based self-test — the harness for the core pure function.

    In the RED commit, case 5 fails with the empty-vs-dirs delta (the
    resolver stub yields nothing, so a manifest-only source emits an
    empty matrix); GREEN wires the resolver and the self-test passes.
    """
    # 1. empty table, no fallback => empty matrix (no invented rows)
    assert manifest_dict_to_matrix({"tools": []}, None) == {"include": []}
    # 2. filled table over both systems, sorted tool order
    assert manifest_dict_to_matrix(
        {"tools": ["subfinder", "garak"]}, None
    ) == {
        "include": [
            {"package": "garak", "system": "x86_64-linux"},
            {"package": "garak", "system": "aarch64-linux"},
            {"package": "subfinder", "system": "x86_64-linux"},
            {"package": "subfinder", "system": "aarch64-linux"},
        ]
    }
    # 3. schema header passes through (mode-agnostic core)
    assert manifest_dict_to_matrix({"schema_version": 1, "tools": []}, None) == {
        "include": []
    }
    # 4. matrix_json renders key-sorted JSON
    assert matrix_json({"tools": ["garak"]}) == (
        '{"include": [{"package": "garak", "system": "x86_64-linux"}, '
        '{"package": "garak", "system": "aarch64-linux"}]}'
    )
    # 5. pkgs/ fallback resolver (the GREEN half of the watched RED): the
    # resolver lists pkgs/ auto-call dirs from the given repo dir,
    # excluding `.nocall` and dirs without a derivation — the same
    # surface pkgs/auto-call.nix filters for. RED ran this against the
    # empty stub and failed with `got []`.
    import tempfile as tempfile_mod

    with tempfile_mod.TemporaryDirectory() as td:
        pkgs = os.path.join(td, "pkgs")
        for name in ("dnsrecon", "subfinder", "skipped-nocall", "skipped-nodrv"):
            d = os.path.join(pkgs, name)
            os.makedirs(d)
            if name != "skipped-nodrv":
                with open(os.path.join(d, "default.nix"), "w") as fh:
                    fh.write("{}\n")
        with open(os.path.join(pkgs, "skipped-nocall", ".nocall"), "w") as fh:
            fh.write("\n")
        got = _pkgs_fallback_names(td)
        assert got == ["dnsrecon", "subfinder"], (
            f"pkgs/ fallback must list the auto-call dirs, got {got!r} — "
            f"a manifest-only source would emit an empty matrix"
        )
    # 6. end-to-end fallback: header-only manifest + real pkgs dirs -> the
    # 2-package matrix (the GREEN output quoted in the GREEN commit body)
    assert manifest_dict_to_matrix(
        {"tools": []}, pkgs_names=["dnsrecon", "subfinder"]
    ) == {
        "include": [
            {"package": "dnsrecon", "system": "x86_64-linux"},
            {"package": "dnsrecon", "system": "aarch64-linux"},
            {"package": "subfinder", "system": "x86_64-linux"},
            {"package": "subfinder", "system": "aarch64-linux"},
        ]
    }
    # 7. fallback with an empty pkgs list stays empty — no invented rows
    assert manifest_dict_to_matrix({"tools": []}, pkgs_names=[]) == {"include": []}
    # 8. lock-node rev extraction (fixture, no network)
    lock = {
        "nodes": {
            "kailash-packages": {
                "locked": {
                    "type": "github",
                    "owner": "kailash-os",
                    "repo": "kailash-packages",
                    "rev": "f29a337ba74a66308624f43aaceadfd17bb21a23",
                }
            }
        }
    }
    import tempfile

    fd, tmp_path = tempfile.mkstemp(suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(lock))
        assert packages_rev_from_flake_lock(tmp_path) == (
            "f29a337ba74a66308624f43aaceadfd17bb21a23"
        )
    finally:
        os.unlink(tmp_path)
    # 9. codeload URL pins the rev; a ref/blank rev is refused
    assert _codeload_url(REPO, "f29a337") == (
        "https://codeload.github.com/kailash-os/kailash-packages/tar.gz/f29a337"
    )
    try:
        _codeload_url(REPO, "")
    except ValueError:
        pass
    else:  # pragma: no cover - guard
        raise AssertionError("blank rev must be refused (no floating heads)")
    # 10. tarball extraction: fixture bytes via a real in-memory tar
    import io
    import tarfile as tarfile_mod

    buf = io.BytesIO()
    with tarfile_mod.open(fileobj=buf, mode="w:gz") as tf:
        manifest_text = "# header\nschema_version: 1\n\ntools: []\n".encode()
        info = tarfile_mod.TarInfo("kailash-packages-f29a337/manifest/tools.yaml")
        info.size = len(manifest_text)
        tf.addfile(info, io.BytesIO(manifest_text))
        drv = b"{}\n"
        info2 = tarfile_mod.TarInfo("kailash-packages-f29a337/pkgs/subfinder/default.nix")
        info2.size = len(drv)
        tf.addfile(info2, io.BytesIO(drv))
    doc, names = manifest_and_pkgs_names_from_tarball(buf.getvalue())
    # shape-only asserts: hold on hosts with and without PyYAML (the
    # schema_version value type differs between the two parsers)
    assert doc.get("tools") == []
    assert doc.get("schema_version") in (1, "1")
    assert names == ["subfinder"]
    # 11. the stdlib fallback parser parses the header-only shape directly
    # (parser-only: holds on hosts with and without PyYAML). Its contract
    # is shape-only: values render as strings, list detection is textual.
    assert _load_yaml_fallback("# header\nschema_version: 1\n\ntools: []\n") == {
        "schema_version": "1",
        "tools": [],
    }
    # 12. the fallback refuses shapes it cannot parse unambiguously
    try:
        _load_yaml_fallback("tools:\n  - id: garak\n")
    except ValueError:
        pass
    else:  # pragma: no cover - guard
        raise AssertionError("structured list entries must fail loudly in the fallback")
    # 13. dict-row contract (§5.2 rows are dicts, KA-05.x): matrix entries
    # derive from bespoke rows' packaging.derivation — native rows are
    # nixpkgs-provided, not overlay buildables. RED probe of the dict
    # shape KA-05.2 lands (current code stringifies whole dicts).
    _rows = [
        {"id": "subfinder", "packaging": {"status": "bespoke",
         "derivation": "pkgs/subfinder/default.nix"}},
        {"id": "nmap", "packaging": {"status": "native"}},
    ]
    assert manifest_dict_to_matrix({"tools": _rows}, None) == {
        "include": [
            {"package": "subfinder", "system": "x86_64-linux"},
            {"package": "subfinder", "system": "aarch64-linux"},
        ]
    }, "dict rows must map bespoke derivations to matrix entries, got %r" % (
        manifest_dict_to_matrix({"tools": _rows}, None),)
    # 14. string rows (fixture-era shape) keep working — the pure core is
    # row-shape agnostic at the call sites that pass plain names.
    assert manifest_dict_to_matrix({"tools": ["subfinder"]}, None) == {
        "include": [
            {"package": "subfinder", "system": "x86_64-linux"},
            {"package": "subfinder", "system": "aarch64-linux"},
        ]
    }
    # 15. a bespoke row missing its derivation path contributes nothing
    # (existence-gating rejects it inside the row walker; the pure core
    # skips non-dict/derivation-less rows defensively).
    _rows2 = [{"id": "lone", "packaging": {"status": "bespoke"}}]
    assert manifest_dict_to_matrix({"tools": _rows2}, None) == {"include": []}
    # 16. seam gate: bespoke derivations not on disk yet → the auto-call
    # fallback (bespoke rows land in KA-05.x ahead of their Wave-5/6
    # derivations; the matrix never carries a phantom leg).
    _filled = {"tools": [
        {"id": "spiderfoot", "packaging": {"status": "bespoke",
         "derivation": "pkgs/spiderfoot/default.nix"}},
        {"id": "subfinder", "packaging": {"status": "bespoke",
         "derivation": "pkgs/subfinder/default.nix"}},
    ]}
    assert matrix_names_for_build(_filled, ["dnsrecon", "subfinder"]) == [
        "subfinder"
    ]
    # 17. seam gate: header-only manifest → the auto-call dirs unchanged.
    assert matrix_names_for_build({"tools": []}, ["dnsrecon", "subfinder"]) == [
        "dnsrecon", "subfinder"
    ]


def main(argv):
    if "--self-test" in argv:
        self_test()
        print("self-test OK")
        return 0
    args = list(argv)
    if "--print-rev" in args:
        # the pinned packages rev from the committed flake.lock (the same
        # node the generator resolves its manifest from)
        print(packages_rev_from_flake_lock(os.path.join(ROOT, "flake.lock")))
        return 0
    manifest_dir = None
    if "--manifest-dir" in args:
        idx = args.index("--manifest-dir")
        try:
            manifest_dir = args[idx + 1]
        except IndexError:
            raise SystemExit("--manifest-dir requires a directory argument")
    if manifest_dir:
        emit(lock_path=None, manifest_dir=manifest_dir)
    else:
        emit(lock_path=os.path.join(ROOT, "flake.lock"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
