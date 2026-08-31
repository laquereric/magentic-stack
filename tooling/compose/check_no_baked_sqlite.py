#!/usr/bin/env python3
"""Fail if the mind-pod app image can still bake host sqlite.

COPY . . does not honour .gitignore. The app gitignores db/*.sqlite3
but until a .dockerignore lists them, every build ships the builder's
dev database (gap 60).

This checker:

  1. Requires runtimes/mind-pod/app/.dockerignore to exist and to
     exclude db/*.sqlite3 and db/*.sqlite3-* (the WAL/SHM siblings).
  2. When MIND_POD_IMAGE is set, runs `find /rails -name '*.sqlite3*'`
     in that image and FAILs on any hit.

Empty CHECK_ROOT fails. 0 examined is not a pass. A skipped image
inspect is reported, not treated as a pass of the image half.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

APP_DIR = "runtimes/mind-pod/app"
DOCKERIGNORE = APP_DIR + "/.dockerignore"
REQUIRED = (
    "db/*.sqlite3",
    "db/*.sqlite3-*",
)


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


def dockerignore_patterns(text: str):
    out = []
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        out.append(s)
    return out


def inspect_image(image: str):
    proc = subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            "--entrypoint",
            "find",
            image,
            "/rails",
            "-name",
            "*.sqlite3*",
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip() or ("exit %d" % proc.returncode)
        return None, err
    hits = [ln.strip() for ln in proc.stdout.splitlines() if ln.strip()]
    return hits, None


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
    examined = 0
    skipped = 0
    skip_reason = ""

    di_path = root / DOCKERIGNORE
    examined += 1
    if not di_path.is_file():
        errors.append("missing %s" % DOCKERIGNORE)
        patterns = []
    else:
        patterns = dockerignore_patterns(di_path.read_text(encoding="utf-8", errors="replace"))
        print("  dockerignore %s (%d patterns)" % (DOCKERIGNORE, len(patterns)))
        for pat in patterns:
            print("    %s" % pat)

    for req in REQUIRED:
        examined += 1
        if req in patterns:
            print("  ok excludes %s" % req)
        else:
            errors.append("%s does not exclude %s" % (DOCKERIGNORE, req))

    image = os.environ.get("MIND_POD_IMAGE", "").strip()
    if image:
        examined += 1
        print("  image %s" % image)
        hits, err = inspect_image(image)
        if err is not None:
            errors.append("image inspect failed (%s): %s" % (image, err))
        elif hits:
            for h in hits:
                errors.append("image %s bakes %s" % (image, h))
        else:
            print("  ok image has no /rails/**/*.sqlite3*")
    else:
        skipped += 1
        skip_reason = "MIND_POD_IMAGE unset; source half only"
        print("  skip image inspect (%s)" % skip_reason)

    ok_pop, _rec = emit_population(examined, skipped=skipped, skipped_reason=skip_reason)
    if not ok_pop:
        return 1
    if errors:
        print("BAKED SQLITE FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print("no baked sqlite: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
