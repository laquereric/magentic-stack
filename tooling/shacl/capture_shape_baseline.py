#!/usr/bin/env python3
"""Step 0: freeze a byte-reproducible shape baseline.

No timestamps. Sorted paths. SHA-256 of file bytes. Checker populations parsed
from the `population:` line only. Run twice and diff the JSON; if they disagree
it is not a baseline.

Does not move TTL, edit shapes, or touch config.shape_root.
"""
from __future__ import annotations
import hashlib, json, os, re, subprocess, sys
from pathlib import Path

ROOT = Path(os.environ.get("CHECK_ROOT") or Path(__file__).resolve().parents[2])

CANON = ROOT / "gems/osi-level-8-profiles"
RUNTIME = ROOT / "gems/rails-osi-level-8/data/osi-level-8"
MANIFEST = ROOT / "tooling/shacl/shape_binding_manifest.json"

CHECKERS = [
    ("validate.py", ROOT / "gems/osi-level-8-profiles/scripts/validate.py", []),
    ("check_shape_drift.py", ROOT / "tooling/shacl/check_shape_drift.py", []),
    ("check_p10_alignment.py", ROOT / "gems/osi-level-8-profiles/scripts/check_p10_alignment.py", []),
    ("check_projection_conformance.py", ROOT / "gems/osi-level-8-profiles/scripts/check_projection_conformance.py", []),
    ("check_cognition_conformance.py", ROOT / "gems/osi-level-8-profiles/scripts/check_cognition_conformance.py", []),
    ("check_shape_binding.py", ROOT / "tooling/shacl/check_shape_binding.py", []),
    ("check_closed.py", ROOT / "tooling/boundary/check_closed.py", []),
    ("check_boundary.py", ROOT / "tooling/boundary/check_boundary.py", []),
    ("check_reversible_pins.py", ROOT / "tooling/pins/check_reversible_pins.py", []),
]


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def ttl_set(base: Path, glob: str) -> dict:
    out = {}
    if not base.exists():
        return out
    for p in sorted(base.glob(glob)):
        if p.is_file() and p.suffix == ".ttl":
            out[rel(p)] = sha256_file(p)
    return out


def git_describe(ref=None):
    def g(*args):
        r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else None
    if ref:
        commit = g("rev-parse", ref + "^{commit}") or g("rev-parse", ref)
        return {
            "commit": commit,
            "commit_short": (commit or "")[:7],
            "branch": None,
            "ref": ref,
            "tag_stack_v0.4.13": g("rev-parse", "stack-v0.4.13^{commit}"),
            "tag_stack_v0.4.12": g("rev-parse", "stack-v0.4.12^{commit}"),
        }
    porcelain = g("status", "--porcelain")
    if porcelain:
        raise SystemExit(
            "FAIL: capture_shape_baseline refuses a dirty tree. "
            "Commit or stash, or pass --ref <commit> so the baseline names a reachable object. "
            "A parent SHA plus a working tree that no longer exists is not a baseline."
        )
    return {
        "commit": g("rev-parse", "HEAD"),
        "commit_short": g("rev-parse", "--short", "HEAD"),
        "branch": g("branch", "--show-current"),
        "tag_stack_v0.4.13": g("rev-parse", "stack-v0.4.13^{commit}"),
        "tag_stack_v0.4.12": g("rev-parse", "stack-v0.4.12^{commit}"),
    }


def run_checker(name, path, extra):
    env = os.environ.copy()
    env["CHECK_ROOT"] = str(ROOT)
    env["EVIDENCE_OUT"] = str(Path("/tmp/shape-baseline-evidence") / (name + ".json"))
    Path(env["EVIDENCE_OUT"]).parent.mkdir(parents=True, exist_ok=True)
    timeout = 180 if name != "check_reversible_pins.py" else 90
    try:
        p = subprocess.run([sys.executable, str(path), *extra], cwd=ROOT,
                           capture_output=True, text=True, env=env, timeout=timeout)
        text = (p.stdout or "") + "\n" + (p.stderr or "")
        m = re.search(r"population:\s+(\d+)\s+examined,\s+(\d+)\s+skipped", text)
        pop = {"examined": int(m.group(1)), "skipped": int(m.group(2))} if m else None
        return {"tool": rel(path),
                "exit": p.returncode, "population": pop,
                "timeout": False}
    except subprocess.TimeoutExpired:
        return {"tool": rel(path), "exit": None, "population": None, "timeout": True}


def nodeshape_token_count(ttl_map):
    n = 0
    for path in ttl_map:
        text = (ROOT / path).read_text(encoding="utf-8", errors="replace")
        n += len(re.findall(r"\ba\s+sh:NodeShape\b", text))
    return n


def build(ref=None):
    canonical = ttl_set(CANON, "profile-*/shapes/*.ttl")
    runtime = ttl_set(RUNTIME, "*.ttl")
    man_digest = sha256_file(MANIFEST) if MANIFEST.is_file() else None
    man = json.loads(MANIFEST.read_text()) if MANIFEST.is_file() else {}
    rows = man.get("shapes") or []
    checkers = [run_checker(n, p, e) for n, p, e in CHECKERS]
    git = git_describe(ref=ref)
    core = {
        "schema": "shape-baseline/v0",
        "git": git,
        "nodeshapes": {
            "unique_local_names": len(rows),
            "declaration_tokens_both_trees": nodeshape_token_count({**canonical, **runtime}),
            "state_counts": (man.get("reconciliation") or {}).get("state_counts"),
            "166_vs_171": {
                "phase0_unique_local_names": 166,
                "now": len(rows),
                "because": "five session response NodeShapes (Session*ContextShape) were written the same day as Phase 0; bound_runtime 35 -> 40. The manifest and checker agree. 166 was not a second population.",
            },
        },
        "ttl_sha256": {
            "canonical_profile_shapes": canonical,
            "runtime_root": runtime,
        },
        "runtime_root_digest_set": {
            "path": "gems/rails-osi-level-8/data/osi-level-8",
            "files": runtime,
            "set_digest": hashlib.sha256(
                json.dumps(runtime, sort_keys=True, separators=(",", ":")).encode()
            ).hexdigest(),
        },
        "manifest_sha256": man_digest,
        "checker_populations": checkers,
        "stack-v0.4.13_bundle_digest": {
            "tag": "stack-v0.4.13",
            "tag_commit": git.get("tag_stack_v0.4.13"),
            "bundle_digest": None,
            "because": "the signed governance-evidence.v1 bundle is produced by the release workflow and is not stored in the tree. This baseline records the tag commit so the bundle can be joined later; it does not invent a digest.",
        },
    }
    # Canonical bytes: sorted keys, no whitespace variance.
    return json.dumps(core, sort_keys=True, indent=2) + "\n"


def main():
    args = [a for a in sys.argv[1:] if a]
    ref = None
    if "--ref" in args:
        i = args.index("--ref")
        ref = args[i + 1]
        args = args[:i] + args[i + 2:]
    out = Path(args[0]) if args else Path("-")
    text = build(ref=ref)
    if str(out) == "-":
        sys.stdout.write(text)
    else:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text)
        print("wrote", out, "sha256", hashlib.sha256(text.encode()).hexdigest())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
