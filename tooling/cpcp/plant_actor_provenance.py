#!/usr/bin/env python3
"""Plant violations against check_actor_provenance.py; each must fail.

clean must exit 0. Every plant must exit non-zero AND say the specific thing,
because exit status alone would pass even if the checker crashed on import.

The first two plants are the defect this gate was built for, restored exactly
as it was written before plan_proven_actor.md S1 removed it. If either ever
stops failing, the gate has stopped doing its job.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECK = ROOT / "tooling/cpcp/check_actor_provenance.py"
PY = sys.executable

# What the checker reads: lib sources under the scanned prefixes. The subject
# is profile9 and ui; copying the gem's whole lib keeps the sandbox honest
# rather than curating it down to the files that happen to match today.
SUBJECT = pathlib.Path("gems/rails-osi-level-8/lib")

MUT = SUBJECT / "rails_osi_level_8/profile9/mutations.rb"
PULLS = SUBJECT / "rails_osi_level_8/profile9/pulls.rb"


def run(root):
    env = dict(os.environ, CHECK_ROOT=str(root))
    p = subprocess.run([PY, str(CHECK)], capture_output=True, text=True, env=env)
    return p.returncode, (p.stdout + p.stderr)


def sandbox():
    d = pathlib.Path(tempfile.mkdtemp(prefix="plant-actor-"))
    dst = d / SUBJECT
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / SUBJECT, dst)
    # population.py is imported by the checker from tooling/, not CHECK_ROOT,
    # so the sandbox needs only the subject tree.
    return d


results = []


def plant(label, mutate, needle):
    d = sandbox()
    try:
        mutate(d)
        rc, out = run(d)
        ok = rc != 0 and needle in out
        results.append((label, ok, "exit %d" % rc if ok else "exit %d, wanted %r" % (rc, needle)))
    finally:
        shutil.rmtree(d, ignore_errors=True)


def edit(d, rel, old, new):
    p = d / rel
    t = p.read_text(encoding="utf-8")
    assert old in t, f"plant did not bite: {old[:60]!r} absent from {rel}"
    p.write_text(t.replace(old, new, 1), encoding="utf-8")


# clean -- also proves the sandbox carries what the checker reads
d = sandbox()
rc, out = run(d)
results.append(("clean", rc == 0, "exit %d" % rc if rc == 0 else out.strip()[-500:]))
shutil.rmtree(d, ignore_errors=True)

# empty CHECK_ROOT
rc, out = run("")
results.append(("empty-root", rc != 0 and "empty CHECK_ROOT" in out, "exit %d" % rc))


# --- THE DEFECT THIS GATE EXISTS FOR ----------------------------------------

def restore_write_default(d):
    """profile9/mutations.rb as it was: an absent actor becomes the constant
    cid:actor:governance-steward, and the ledger row says a steward acted."""
    edit(d, MUT, '"actorCid" => actor_cid,',
         '"actorCid" => params["actorCid"].to_s.empty? ? Graph.j1_actor_cid : params["actorCid"],')


plant("write-default-to-constant-fails", restore_write_default,
      "falls back to a seeded constant")


def restore_capability_default(d):
    """profile9/pulls.rb as it was: a PageRenderBundle capability naming the
    constant actor alongside canCommitEffect true."""
    edit(d, PULLS, '"actorCid" => actor_cid,',
         '"actorCid" => Request.present?(params["actorCid"]) ? params["actorCid"] : Graph.j1_actor_cid,')


plant("capability-default-to-constant-fails", restore_capability_default,
      "falls back to a seeded constant")


# --- the symmetry rule ------------------------------------------------------

def drop_write_requirement(d):
    """Records an actor from caller params without requiring it -- the
    read/write asymmetry, reintroduced."""
    edit(d, MUT, 'actor_cid = Request.require_cid!(params, "actorCid")',
         'actor_cid = params["actorCid"].to_s')


plant("write-without-require-fails", drop_write_requirement,
      "never require_cid!")


def drop_read_requirement(d):
    edit(d, PULLS, 'actor_cid = Request.require_cid!(params, "actorCid")',
         'actor_cid = params["actorCid"].to_s')


plant("read-without-require-fails", drop_read_requirement,
      "never require_cid!")


# --- the gate must refuse an empty population -------------------------------

def strip_all_actors(d):
    """No lib source names an actor at all. A checker that reports OK over
    nothing is the failure this repo refuses everywhere else."""
    for p in (d / SUBJECT).rglob("*.rb"):
        t = p.read_text(encoding="utf-8", errors="replace")
        if "actorCid" in t:
            p.write_text(t.replace("actorCid", "somethingElse"), encoding="utf-8")


plant("empty-population-fails", strip_all_actors, "looking at nothing")

print("plant | ok | detail")
print("------|----|--------")
bad = 0
for name, ok, detail in results:
    print("%s | %s | %s" % (name, str(ok).lower(), detail))
    if not ok:
        bad += 1
print("plant actor-provenance: %s (%d/%d)" % ("OK" if not bad else "FAIL",
                                              len(results) - bad, len(results)))
raise SystemExit(1 if bad else 0)
