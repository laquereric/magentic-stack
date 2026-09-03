#!/usr/bin/env python3
"""Gate ADR 0047's three-language rule.

Python => mind. Rust => switch. Everything else Ruby (Rails form).
Exemption (graph): third-party, unforked, digest-pinned, we ship no source
into it. A new container must MEET those conditions, not inherit the name.

Violation (switch): Node today, target Rust, row 11. A violation is not
an exemption -- separate list, each entry has a reason.

Population: containers examined AND source files examined.
Empty CHECK_ROOT fails. 0 examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

RULE_FILE = Path("tooling/compose/language_rule.json")
COMPOSE_FILES = (
    "runtimes/mind-pod/docker-compose.yml",
    "runtimes/mind-pod/app/extract/compose.yml",
)
SOURCE_TREES = (
    "runtimes/mind-pod/mind",
    "runtimes/switch",
    "runtimes/mind-pod/app",
)
SKIP_DIR = frozenset({".git", "vendor", "node_modules", ".bundle", "__pycache__"})
LANG_EXT = {
    ".py": "python",
    ".rb": "ruby",
    ".rs": "rust",
    ".mjs": "javascript",
    ".js": "javascript",
}
SERVICE_RE = re.compile(r"^  ([A-Za-z0-9_-]+):\s*$")
IMAGE_RE = re.compile(r"^    image:\s*(.+)$")
BUILD_RE = re.compile(r"^    build:")
VOL_INLINE = re.compile(r"^    volumes:\s*\[(.+)\]")


def fail_empty_check_root():
    if "CHECK_ROOT" in os.environ and not str(os.environ.get("CHECK_ROOT", "")).strip():
        print("FAIL: empty CHECK_ROOT", file=sys.stderr)
        return True
    return False


def root_from_env():
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    return Path(raw)


def parse_services(path: Path):
    services = {}
    current = None
    in_services = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("services:"):
            in_services = True
            current = None
            continue
        if in_services and re.match(r"^[A-Za-z]", line):
            in_services = False
            current = None
            continue
        if not in_services:
            continue
        m = SERVICE_RE.match(line)
        if m:
            current = m.group(1)
            services.setdefault(current, {"image": "", "build": False, "volumes": ""})
            continue
        if current is None:
            continue
        m = IMAGE_RE.match(line)
        if m:
            services[current]["image"] = m.group(1).strip().strip('"').strip("'")
        if BUILD_RE.match(line):
            services[current]["build"] = True
        m = VOL_INLINE.match(line)
        if m:
            services[current]["volumes"] = m.group(1)
    return services


def observed_language(svc, meta, root: Path) -> str:
    image = meta.get("image") or ""
    if "oxigraph" in image.lower():
        return "third_party"
    if meta.get("build"):
        # Prefer Dockerfile FROM when we can find one.
        for rel in (
            "runtimes/mind-pod/mind/Dockerfile",
            "runtimes/switch/Dockerfile",
            "runtimes/mind-pod/app/Dockerfile",
        ):
            p = root / rel
            if not p.is_file():
                continue
            first = ""
            for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
                if line.startswith("FROM "):
                    first = line.lower()
                    break
            if "mind" in svc and "mind" in rel:
                if "python" in first:
                    return "python"
            if svc == "switch" and "switch" in rel:
                if "node" in first:
                    return "node"
            if svc in ("back", "backjob", "front", "vault", "config", "shape", "bus") and rel.endswith("app/Dockerfile"):
                if "ruby" in first or "rails" in first or "mind-pod-rails" in first:
                    return "ruby"
    if image.startswith("mind-pod") and "mind" not in image.split(":")[0].replace("mind-pod", ""):
        # mind-pod:latest / mind-pod:demo = Rails image
        if svc != "mind":
            return "ruby"
    if "mind-pod-mind" in image:
        return "python"
    if "mind-pod-switch" in image or "node:" in image:
        return "node"
    if image.startswith("mind-pod"):
        return "ruby"
    return "unknown"


def exemption_holds(meta) -> tuple[bool, str]:
    image = meta.get("image") or ""
    reasons = []
    if "@sha256:" not in image:
        reasons.append("not digest-pinned")
    if meta.get("build"):
        reasons.append("has a build context (we ship source)")
    if "oxigraph" not in image.lower() and "mind-pod" in image:
        reasons.append("not third-party (mind-pod image)")
    vols = meta.get("volumes") or ""
    # bind mount looks like a host path before the colon, not a named volume
    if "/" in vols.split(":")[0] if vols else False:
        reasons.append("bind-mounts our tree")
    if reasons:
        return False, "; ".join(reasons)
    return True, "third-party, unforked, digest-pinned, no source"


def walk_sources(root: Path, rel: str) -> int:
    base = root / rel
    if not base.is_dir():
        return 0
    n = 0
    for p in base.rglob("*"):
        if not p.is_file():
            continue
        rel_parts = p.relative_to(base).parts
        if any(part in SKIP_DIR for part in rel_parts):
            continue
        if p.suffix in LANG_EXT:
            n += 1
    return n


def main():
    if fail_empty_check_root():
        return 1
    root = root_from_env()
    if not root.is_dir():
        print("FAIL: CHECK_ROOT is not a directory: %s" % root, file=sys.stderr)
        return 1
    try:
        nonempty = any(root.iterdir())
    except OSError as e:
        print("FAIL: CHECK_ROOT unreadable: %s" % e, file=sys.stderr)
        return 1
    if not nonempty:
        print("FAIL: empty CHECK_ROOT tree", file=sys.stderr)
        return 1

    errors = []
    rule_path = root / RULE_FILE
    if not rule_path.is_file():
        print("FAIL: missing %s" % RULE_FILE.as_posix(), file=sys.stderr)
        emit_population(0)
        return 1
    rule = json.loads(rule_path.read_text(encoding="utf-8"))
    expected = rule.get("rule") or {}
    exemptions = {e["service"]: e for e in (rule.get("exemptions") or [])}
    violations = {v["service"]: v for v in (rule.get("violations") or [])}

    for name, row in list(exemptions.items()) + list(violations.items()):
        if not (row.get("reason") or "").strip():
            errors.append("%s %s has no reason" % (row.get("kind"), name))
        if row.get("kind") not in ("exemption", "violation"):
            errors.append("%s missing kind exemption|violation" % name)
    overlap = set(exemptions) & set(violations)
    if overlap:
        errors.append("service in both exemptions and violations: %s" % sorted(overlap))

    services = {}
    for rel in COMPOSE_FILES:
        p = root / rel
        if not p.is_file():
            errors.append("missing compose %s" % rel)
            continue
        for name, meta in parse_services(p).items():
            services.setdefault(name, meta)

    containers = 0
    for name, meta in sorted(services.items()):
        containers += 1
        obs = observed_language(name, meta, root)
        print("  container %s observed=%s image=%s build=%s" % (
            name, obs, meta.get("image", "")[:60], meta.get("build")))

        if name in exemptions:
            ok, why = exemption_holds(meta)
            print("    exemption: %s (%s)" % (why, exemptions[name].get("reason", "")[:80]))
            if not ok:
                errors.append("exemption %s does not meet conditions: %s" % (name, why))
            continue
        if name in violations:
            v = violations[name]
            print("    violation: %s (target %s; %s)" % (
                v.get("observed"), v.get("target"), (v.get("reason") or "")[:80]))
            if v.get("kind") != "violation":
                errors.append("%s listed as violation but kind=%s" % (name, v.get("kind")))
            continue

        want = expected.get(name) or expected.get("default")
        if name == "mind":
            want = expected.get("mind", "python")
        elif name == "switch":
            want = expected.get("switch", "rust")
        else:
            want = expected.get("default", "ruby")
        if obs != want:
            errors.append(
                "%s language %s != %s (not exempt, not a named violation)"
                % (name, obs, want)
            )
        else:
            print("    ok expected=%s" % want)

    sources = 0
    for rel in SOURCE_TREES:
        n = walk_sources(root, rel)
        sources += n
        print("  sources %s: %d files" % (rel, n))

    print("  containers examined: %d" % containers)
    print("  source files examined: %d" % sources)
    ok_pop, _ = emit_population(containers + sources, skipped=0)
    if not ok_pop:
        return 1
    if containers == 0 or sources == 0:
        print("FAIL: empty containers or source-files population", file=sys.stderr)
        return 1
    if errors:
        print("LANGUAGE RULE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("language rule: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
