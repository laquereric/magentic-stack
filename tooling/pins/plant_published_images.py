#!/usr/bin/env python3
"""Plant violations against check_published_images.py; each must fail.

clean must exit 0. Every plant must exit non-zero, so the gate is shown to
detect the thing it claims to detect rather than merely passing today.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHECK = os.path.join(ROOT, "tooling/pins/check_published_images.py")
PY = sys.executable


def run(root):
    env = dict(os.environ, CHECK_ROOT=root)
    p = subprocess.run([PY, CHECK], capture_output=True, text=True, env=env)
    return p.returncode, (p.stdout + p.stderr)


def sandbox():
    """Copy just what the checker reads: .gitmodules, the ledger, the publish
    workflow, Dockerfiles.

    The workflow joined that list when the checker started holding declared
    platforms against what the workflow builds. Leaving it out made the CLEAN
    case fail -- the checker correctly reporting a missing file that the sandbox
    simply had not copied. A plant is only as honest as its sandbox is complete.
    """
    d = tempfile.mkdtemp(prefix="plant-pub-")
    for rel in (".gitmodules", "tooling/pins/published_images.json",
                ".github/workflows/publish-images.yml"):
        src = os.path.join(ROOT, rel)
        if os.path.isfile(src):
            os.makedirs(os.path.join(d, os.path.dirname(rel)), exist_ok=True)
            shutil.copy(src, os.path.join(d, rel))
    led = json.load(open(os.path.join(ROOT, "tooling/pins/published_images.json")))
    for e in led.get("published", []) + led.get("not_published", []):
        rel = e["dockerfile"]
        src = os.path.join(ROOT, rel)
        if os.path.isfile(src):
            os.makedirs(os.path.join(d, os.path.dirname(rel)), exist_ok=True)
            shutil.copy(src, os.path.join(d, rel))
    return d


def ledger(d):
    return json.load(open(os.path.join(d, "tooling/pins/published_images.json")))


def write(d, led):
    json.dump(led, open(os.path.join(d, "tooling/pins/published_images.json"), "w"), indent=2)


results = []

# clean
d = sandbox()
rc, out = run(d)
results.append(("clean", rc == 0, "exit %d" % rc))
shutil.rmtree(d)

# empty CHECK_ROOT
rc, out = run("")
results.append(("empty-root", rc != 0, "exit %d" % rc))

# empty tree: no Dockerfile anywhere
d = tempfile.mkdtemp(prefix="plant-pub-empty-")
os.makedirs(os.path.join(d, "tooling/pins"), exist_ok=True)
shutil.copy(os.path.join(ROOT, "tooling/pins/published_images.json"),
            os.path.join(d, "tooling/pins/published_images.json"))
rc, out = run(d)
results.append(("empty-tree-fails", rc != 0 and "empty CHECK_ROOT tree" in out, "exit %d" % rc))
shutil.rmtree(d)

# an undeclared Dockerfile appears
d = sandbox()
os.makedirs(os.path.join(d, "runtimes/newthing"), exist_ok=True)
open(os.path.join(d, "runtimes/newthing/Dockerfile"), "w").write("FROM scratch\n")
rc, out = run(d)
results.append(("undeclared-fails", rc != 0 and "undeclared Dockerfile" in out, "exit %d" % rc))
shutil.rmtree(d)

# a published entry names a Dockerfile that is not there
d = sandbox()
led = ledger(d)
led["published"].append({"name": "ghost", "dockerfile": "runtimes/ghost/Dockerfile",
                         "context": ".", "because": "planted"})
write(d, led)
rc, out = run(d)
results.append(("ghost-published-fails", rc != 0 and "missing Dockerfile" in out, "exit %d" % rc))
shutil.rmtree(d)

# not_published without a because
d = sandbox()
led = ledger(d)
led["not_published"][0]["because"] = ""
write(d, led)
rc, out = run(d)
results.append(("silent-exclusion-fails", rc != 0 and "missing because" in out, "exit %d" % rc))
shutil.rmtree(d)

# the same Dockerfile declared both ways
d = sandbox()
led = ledger(d)
led["not_published"].append({"dockerfile": led["published"][0]["dockerfile"],
                             "because": "planted"})
write(d, led)
rc, out = run(d)
results.append(("both-lists-fails", rc != 0 and "both published and not_published" in out,
                "exit %d" % rc))
shutil.rmtree(d)

# a mutable tagging rule
d = sandbox()
led = ledger(d)
led["tagging"]["rule"] = "latest"
write(d, led)
rc, out = run(d)
results.append(("mutable-tag-fails", rc != 0 and "commit SHA" in out, "exit %d" % rc))
shutil.rmtree(d)

# ARCHITECTURE DECLARED IN ONLY ONE PLACE IS NOT DECLARED.
#
# The images were amd64 because the runner was, with nothing saying so, and a
# consumer met it as "no match for platform in manifest list". Both halves have
# to fail on their own: a ledger that claims a platform the workflow does not
# build, and a workflow that builds whatever it likes while the ledger claims
# something.
d = sandbox()
wf = os.path.join(d, ".github/workflows/publish-images.yml")
text = open(wf).read()
open(wf, "w").write("\n".join(
    l for l in text.splitlines() if l.strip() != "platforms: linux/amd64"
) + "\n")
rc, out = run(d)
results.append(("workflow-without-platforms-fails", rc != 0 and "names no platforms" in out,
                "exit %d" % rc))
shutil.rmtree(d)

d = sandbox()
led = ledger(d)
led.pop("platforms", None)
write(d, led)
rc, out = run(d)
results.append(("ledger-without-platforms-fails", rc != 0 and "declares no platforms" in out,
                "exit %d" % rc))
shutil.rmtree(d)

# The two agreeing on DIFFERENT values is the drift the pair exists to catch.
d = sandbox()
led = ledger(d)
led["platforms"] = ["linux/amd64", "linux/arm64"]
write(d, led)
rc, out = run(d)
results.append(("platforms-disagree-fails", rc != 0 and "while the ledger declares" in out,
                "exit %d" % rc))
shutil.rmtree(d)

print("plant | ok | detail")
print("------|----|--------")
bad = 0
for name, ok, detail in results:
    print("%s | %s | %s" % (name, str(ok).lower(), detail))
    if not ok:
        bad += 1
print("plant published-images: %s" % ("OK" if not bad else "FAIL"))
raise SystemExit(1 if bad else 0)
