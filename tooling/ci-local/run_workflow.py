#!/usr/bin/env python3
"""Run a workflow's `run:` steps here, in order, and refuse if the box is wrong.

DERIVED, NOT COPIED. A local gate that restates what the workflow does is a
second answer to one question, and the two drift -- which is the same defect
this repo already records against six workflows that re-ask what bin/sweep
asks. So the steps are READ from .github/workflows/main-green.yml at run time.
Change the workflow and this follows; there is nothing here to keep in sync.

`uses:` steps are the runner's job and cannot execute here: checkout@v4 is the
clean tree the caller mounted, setup-python and setup-ruby are the image. They
are not silently skipped -- the versions they ASK for are read out of the
workflow and checked against what this container actually has, so a workflow
that moves to a new ruby fails loudly here instead of testing the wrong thing
quietly.

Exit 0 only if every `run:` step exits 0.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("run_workflow: PyYAML is required in the image")

ROOT = Path(os.environ.get("CI_LOCAL_ROOT", "/work"))


def bold(msg: str) -> None:
    print("\n\033[1m==> %s\033[0m" % msg, flush=True)


def version_of(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        return "unavailable (%s)" % exc
    text = (out.stdout or out.stderr or "").strip()
    m = re.search(r"(\d+\.\d+(\.\d+)?)", text)
    return m.group(1) if m else text


def check_toolchain(steps: list[dict]) -> list[str]:
    """Hold the image against the versions the workflow's uses: steps ask for."""
    problems = []
    wanted_py = wanted_rb = None
    for st in steps:
        uses = str(st.get("uses") or "")
        with_ = st.get("with") or {}
        if "setup-python" in uses:
            wanted_py = str(with_.get("python-version") or "").strip()
        elif "setup-ruby" in uses:
            wanted_rb = str(with_.get("ruby-version") or "").strip()

    have_py = version_of([sys.executable, "-V"])
    have_rb = version_of(["ruby", "-v"])
    print("  python: image %s / workflow asks %s" % (have_py, wanted_py or "-"))
    print("  ruby:   image %s / workflow asks %s" % (have_rb, wanted_rb or "-"))

    # Prefix match: the workflow asks for a SERIES ('3.12', '3.3') and the image
    # pins a patch. A mismatch is a failure rather than a note -- testing ruby
    # 3.2 against a workflow that runs 3.3 is the class of lie this gate exists
    # to stop.
    if wanted_py and not have_py.startswith(wanted_py):
        problems.append("image python %s does not satisfy workflow %s" % (have_py, wanted_py))
    if wanted_rb and not have_rb.startswith(wanted_rb):
        problems.append("image ruby %s does not satisfy workflow %s" % (have_rb, wanted_rb))
    return problems


def emulate_uses(step: dict, env: dict):
    """Reproduce the SIDE EFFECTS of a uses: step, not just the tool it installs.

    Returns None when there is nothing to do, else the exit code.

    setup-ruby with `bundler-cache: true` is the one that matters here, and it
    caught this gate out on its first honest run. That input does not merely
    put a ruby on PATH -- it runs `bundle install` for the Gemfile. The image
    supplies ruby, so treating the whole step as "provided by the image" looked
    reasonable and was wrong: the ROOT bundle was never installed, and the four
    .rb plants bin/sweep runs under `bundle exec ruby` died inside
    bundler/setup with a gem_prelude backtrace that names nothing useful.

    Reproduced rather than worked around. A gate that skips the expensive half
    of a CI step and reports green has told you the opposite of what you asked.
    """
    uses = str(step.get("uses") or "")
    with_ = step.get("with") or {}
    if "setup-ruby" not in uses:
        return None
    cache = str(with_.get("bundler-cache", "")).strip().lower()
    if cache not in ("true", "yes", "1"):
        return None
    wd = str(with_.get("working-directory") or "").strip()
    cwd = (ROOT / wd) if wd else ROOT
    # FROZEN, because the action is. That is not a detail: a Gemfile.lock
    # missing a gem the Gemfile names fails here with "the lockfile can't be
    # updated because frozen mode is set", which is precisely how gate-main-green
    # died in setup for weeks while every developer's unfrozen `bundle install`
    # quietly rewrote the lock and moved on. A gate that installs unfrozen
    # cannot see the defect it most needs to.
    frozen = dict(env, BUNDLE_FROZEN="true")
    bold("emulating %s bundler-cache (frozen) in %s" % (uses.split("@")[0], cwd))
    return subprocess.run(["bundle", "install", "--jobs", "4"],
                          cwd=str(cwd), env=frozen).returncode


def main() -> int:
    wf_rel = os.environ.get("CI_LOCAL_WORKFLOW", ".github/workflows/main-green.yml")
    wf = ROOT / wf_rel
    if not wf.is_file():
        print("run_workflow: no workflow at %s" % wf, file=sys.stderr)
        return 1

    doc = yaml.safe_load(wf.read_text(encoding="utf-8"))
    jobs = doc.get("jobs") or {}
    if not jobs:
        print("run_workflow: %s declares no jobs" % wf_rel, file=sys.stderr)
        return 1

    rc_total = 0
    for job_name, job in jobs.items():
        steps = job.get("steps") or []
        if not steps:
            continue
        bold("job %s (%s)" % (job_name, wf_rel))

        problems = check_toolchain(steps)
        if problems:
            for p in problems:
                print("  FAIL %s" % p, file=sys.stderr)
            return 1

        env = os.environ.copy()
        for k, v in (job.get("env") or {}).items():
            env[str(k)] = str(v)

        ran = 0
        for st in steps:
            name = str(st.get("name") or st.get("uses") or "step")
            run = st.get("run")
            if not run:
                side = emulate_uses(st, env)
                if side is None:
                    print("  -- provided by the image/mount: %s" % name)
                elif side != 0:
                    print("\n  FAIL emulating %r exited %d" % (name, side), file=sys.stderr)
                    return side
                continue
            for k, v in (st.get("env") or {}).items():
                env[str(k)] = str(v)
            bold("step: %s" % name)
            # bash -e: the workflow's default shell semantics for multi-line run.
            proc = subprocess.run(["bash", "-eo", "pipefail", "-c", str(run)],
                                  cwd=str(ROOT), env=env)
            ran += 1
            if proc.returncode != 0:
                print("\n  FAIL step %r exited %d" % (name, proc.returncode), file=sys.stderr)
                return proc.returncode
        # Zero executable steps means the derivation found nothing -- a green
        # report over an empty population, which this repo refuses everywhere.
        if ran == 0:
            print("  FAIL job %s has no run: steps to execute" % job_name, file=sys.stderr)
            return 1
        print("\n  ok job %s: %d run-step(s) passed" % (job_name, ran))
    return rc_total


if __name__ == "__main__":
    raise SystemExit(main())
