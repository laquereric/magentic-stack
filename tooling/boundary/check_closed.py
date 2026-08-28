#!/usr/bin/env python3
# Assert magentic-stack is CLOSED: code here has no other home.
#
# ADR 0038. The monorepo used to mirror its gems out to standalone repos via
# subtree remotes. Those repos are archived and the remotes are gone -- but
# nothing stopped a new outward pointer from appearing, and closure that is not
# enforced drifts back. This is the constraint ADR 0038's enforced_by names.
#
# FAILS CLOSED: finding nothing to check is an error. A conformance check with an
# empty population reports success otherwise, which reads as coverage it has not
# got.
import json
import os
import sys
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
VENDOR_DIRS = ("gems", "tooling", "runtimes")
OWN_PREFIX = "https://github.com/laquereric/"
HOME_REPO = "magentic-stack"

# Genuine third-party upstreams: FOLLOW-THEM, pinned, never forked, and
# legitimately hosted elsewhere. Closure is about OUR code, not theirs.
ALLOWED_SUBMODULE_URLS = (
    "https://github.com/NVIDIA-NeMo/labs-OO-Agents",
    "https://github.com/NVIDIA-NeMo/Switchyard",
)

STOP = set(' "' + "'" + ")>,;`|\n\t")


def own_repos_named_in(text):
    """Every laquereric/<repo> mentioned, by name."""
    found = []
    idx = text.find(OWN_PREFIX)
    while idx != -1:
        rest = text[idx + len(OWN_PREFIX):]
        name = ""
        for ch in rest:
            if ch in STOP or ch == "/":
                break
            name += ch
        if name.endswith(".git"):
            name = name[:-4]
        if name:
            found.append(name)
        idx = text.find(OWN_PREFIX, idx + 1)
    return found


def gemspecs():
    out = []
    for d in VENDOR_DIRS:
        out.extend(sorted((ROOT / d).glob("*/*.gemspec")))
    return out


def read(p):
    return p.read_text(encoding="utf-8", errors="replace")


def check_gemspecs_point_home(results):
    specs = gemspecs()
    if not specs:
        results.append(("gemspecs-found", False,
                        "no gemspecs under " + ", ".join(VENDOR_DIRS) + " -- nothing to check"))
        return
    bad = []
    for spec in specs:
        for repo in own_repos_named_in(read(spec)):
            if repo != HOME_REPO:
                bad.append(str(spec.relative_to(ROOT)) + " -> laquereric/" + repo)
    results.append(("gemspecs-point-home", not bad,
                    "clean (%d gemspecs)" % len(specs) if not bad else "; ".join(sorted(bad))))


def check_no_nested_git(results):
    """A .git inside a vendored dir is a second source of truth for that code."""
    nested = []
    for d in VENDOR_DIRS:
        for child in sorted((ROOT / d).glob("*/.git")):
            nested.append(str(child.parent.relative_to(ROOT)))
    results.append(("no-nested-git", not nested,
                    "clean" if not nested else "nested repo in " + ", ".join(nested)))


def check_submodules_are_upstreams(results):
    gm = ROOT / ".gitmodules"
    if not gm.exists():
        results.append(("submodules-are-upstreams", True, "no submodules"))
        return
    urls = [ln.split("=", 1)[1].strip()
            for ln in read(gm).splitlines() if ln.strip().startswith("url")]
    if not urls:
        results.append(("submodules-are-upstreams", False, ".gitmodules present but declares no url"))
        return
    bad = [u for u in urls if u.rstrip("/").removesuffix(".git") not in ALLOWED_SUBMODULE_URLS]
    results.append(("submodules-are-upstreams", not bad,
                    "clean (%d pinned upstreams)" % len(urls) if not bad
                    else "unexpected submodule: " + ", ".join(bad)))


def check_every_gem_is_built(results):
    """A gem that is the sole copy and is never loaded is unverified truth."""
    gemfile = ROOT / "Gemfile"
    if not gemfile.exists():
        results.append(("every-gem-is-built", False, "no root Gemfile"))
        return
    text = read(gemfile)
    missing = []
    for spec in gemspecs():
        name = spec.parent.name
        if ('path: "%s"' % spec.parent.relative_to(ROOT)) not in text:
            missing.append(name)
    results.append(("every-gem-is-built", not missing,
                    "clean" if not missing else "absent from root Gemfile: " + ", ".join(sorted(missing))))


def check_osi8_docs_not_duplicated(results):
    # grammar/ holds the base spec; gems/ holds the profiles package (ADR 0022).
    # Six profile docs were once byte-identical in both. Two copies of one
    # document is not a cross-reference, it is a fork waiting to happen.
    # LICENSE is exempt: a package legitimately carries its own.
    base = ROOT / "grammar" / "osi-level-8"
    pkg = ROOT / "gems" / "osi-level-8-profiles"
    if not base.is_dir() or not pkg.is_dir():
        results.append(("osi8-docs-not-duplicated", False,
                        "expected both grammar/osi-level-8 and gems/osi-level-8-profiles"))
        return
    dupes = []
    for f in base.rglob("*"):
        if not f.is_file() or ".git" in f.parts or f.name == "LICENSE":
            continue
        twin = pkg / f.relative_to(base)
        if twin.is_file() and twin.read_bytes() == f.read_bytes():
            dupes.append(str(f.relative_to(ROOT)))
    results.append(("osi8-docs-not-duplicated", not dupes,
                    "clean" if not dupes
                    else "duplicated in both trees: " + ", ".join(sorted(dupes))))


def check_no_vendor_references(results):
    # vendor/ does not exist in this repo and is not coming back: the galaxy moved
    # to gems/. A reference to it is therefore always dead, and that is not
    # theoretical -- on 2026-08-27 three were found in mind-pod, one of them a CI
    # step running app/bin/prepare, a script deleted by e215ea1. Gate 1 Part C ran
    # it under bash -e, so the gate failed on a line nobody had noticed.
    #
    # Scoped to what this repo OWNS. upstreams/ is third-party (nemo-switchyard
    # tests use vendor/model-name as an IDENTIFIER, not a path), and
    # vendor/bundle | vendor/cache are Bundler own paths, named in dockerignore
    # rules where they are correct.
    owned = ("runtimes", "gems", "tooling", "grammar", ".github", "bin")
    skip = ("vendor/bundle", "vendor/cache", "mind/vendor/")
    hits = []
    for area in owned:
        base = ROOT / area
        if not base.is_dir():
            continue
        for f in base.rglob("*"):
            if not f.is_file() or ".git" in f.parts or "upstreams" in f.parts:
                continue
            # An ignore RULE is a declaration about a path that may be created
            # later, not a reference to one that must exist.
            if f.name in (".gitignore", ".dockerignore"):
                continue
            # This file names the patterns it looks for; it is not a reference.
            if f.resolve() == Path(__file__).resolve():
                continue
            # mind/ builds its own vendor/nooa via mind/bin/prepare from the
            # pinned upstreams/nooa submodule -- build-time, and real.
            if "mind" in f.parts and "mind-pod" in str(f):
                continue
            if f.suffix not in (".rb", ".yml", ".yaml", ".sh", ".py", ""):
                continue
            try:
                text = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for n, line in enumerate(text.splitlines(), 1):
                if "vendor/" not in line or any(s in line for s in skip):
                    continue
                if line.lstrip().startswith(("#", "//")):
                    continue
                hits.append("%s:%d" % (f.relative_to(ROOT), n))
    results.append(("no-vendor-references", not hits,
                    "clean" if not hits else "vendor/ is gone; referenced at " + ", ".join(sorted(hits)[:5])))


def main():
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from population import emit_population

    results = []
    specs = gemspecs()
    vendor_dirs = [d for d in VENDOR_DIRS if (ROOT / d).is_dir()]
    populated, pop = emit_population(
        len(specs),
        skipped=len(VENDOR_DIRS) - len(vendor_dirs),
        skipped_reason="vendor dir absent",
    )
    if not populated:
        print(json.dumps({"checks": [], "population": pop}, indent=2))
        return 1

    check_gemspecs_point_home(results)
    check_no_nested_git(results)
    check_submodules_are_upstreams(results)
    check_every_gem_is_built(results)
    check_osi8_docs_not_duplicated(results)
    check_no_vendor_references(results)

    report = [{"assertion": a, "ok": ok, "detail": d} for a, ok, d in results]
    print(json.dumps({"checks": report, "population": pop}, indent=2))

    failures = [r for r in results if not r[1]]
    if failures:
        print("monorepo closure: FAILED (%d of %d)" % (len(failures), len(results)), file=sys.stderr)
        for a, _, d in failures:
            print("  %s: %s" % (a, d), file=sys.stderr)
        return 1
    print("monorepo closure: OK (%d checks)" % len(results))
    return 0


if __name__ == "__main__":
    sys.exit(main())
