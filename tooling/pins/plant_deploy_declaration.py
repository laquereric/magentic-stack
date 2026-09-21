#!/usr/bin/env python3
"""Plant violations against check_deploy_declaration.py; each must fail.

clean must exit 0. Every plant must exit non-zero AND say the specific thing,
so the gate is shown to detect what it claims rather than merely being red for
some other reason -- exit status alone would pass even if the checker crashed.

The first two plants are the defects that motivated the gate: the front-base
declaration removed, and a hook naming a file that is not there. If either of
those ever stops failing, this gate has stopped doing the job it was built for.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHECK = os.path.join(ROOT, "tooling/pins/check_deploy_declaration.py")
PY = sys.executable
DEPLOY = ".cpcp/deploy.json"

# Everything the checker reads. If this list is short, the CLEAN case fails
# loudly rather than the plants passing for the wrong reason -- which is the
# only reason it is safe to write the list by hand.
COPY = [
    DEPLOY,
    "runtimes/mind-pod/app/extract/compose.yml",
    "runtimes/mind-pod/docker-compose.yml",
    "runtimes/rails-base/Dockerfile",
    "runtimes/rails-base/FLOOR.json",
    "runtimes/front-base/Dockerfile",
    "runtimes/front-base/FLOOR-FRONT.json",
    "runtimes/mind-pod/app/Dockerfile",
    "runtimes/mind-pod/front/Dockerfile",
    "runtimes/mind-pod/mind/Dockerfile",
    "runtimes/mind-pod/mind/bin/prepare",
    "gems/adapters/nemo-switchyard/Dockerfile",
]


def run(root):
    env = dict(os.environ, CHECK_ROOT=root)
    p = subprocess.run([PY, CHECK], capture_output=True, text=True, env=env)
    return p.returncode, (p.stdout + p.stderr)


def sandbox():
    d = tempfile.mkdtemp(prefix="plant-deploy-")
    for rel in COPY:
        src = os.path.join(ROOT, rel)
        if os.path.isfile(src):
            os.makedirs(os.path.join(d, os.path.dirname(rel)), exist_ok=True)
            shutil.copy(src, os.path.join(d, rel))
    return d


def load(d):
    with open(os.path.join(d, DEPLOY), encoding="utf-8") as fh:
        return json.load(fh)


def write(d, data):
    with open(os.path.join(d, DEPLOY), "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)


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


# clean -- also proves COPY is complete
d = sandbox()
rc, out = run(d)
results.append(("clean", rc == 0, "exit %d" % rc if rc == 0 else out.strip()[-600:]))
shutil.rmtree(d, ignore_errors=True)

# empty CHECK_ROOT
rc, out = run("")
results.append(("empty-root", rc != 0 and "empty CHECK_ROOT" in out, "exit %d" % rc))


# --- THE TWO DEFECTS THIS GATE EXISTS FOR ---------------------------------

def undeclare_front_base(d):
    """Exactly the state the repo was in: compose builds front FROM a base
    that the declaration does not mention anywhere."""
    data = load(d)
    data["local_deploy"]["images"].pop("front_base", None)
    data["stack"]["build"].pop("front_base", None)
    data["up_env"].pop("front_base", None)
    write(d, data)


plant("front-base-undeclared-fails", undeclare_front_base, "front-base was exactly")


def ghost_hook(d):
    data = load(d)
    data["hooks"]["before_up"].append("runtimes/mind-pod/app/bin/prepare")
    write(d, data)


plant("missing-hook-fails", ghost_hook, "names a missing file")


# --- structure -------------------------------------------------------------

def tag_as_digest(d):
    data = load(d)
    data["local_deploy"]["images"]["nats"]["digest"] = "nats:2.11.16"
    write(d, data)


plant("tag-is-not-a-pin-fails", tag_as_digest, "a tag is not a pin")


def no_because(d):
    data = load(d)
    data["local_deploy"]["images"]["oxigraph"]["because"] = ""
    write(d, data)


plant("silent-image-fails", no_because, "has no because")


# --- floor, both ways ------------------------------------------------------

def floor_drift(d):
    data = load(d)
    data["local_deploy"]["images"]["rails_floor"]["digest"] = "sha256:" + ("b" * 64)
    write(d, data)


plant("floor-digest-drift-fails", floor_drift, "disagrees with")


def unclaimed_floor(d):
    data = load(d)
    data["local_deploy"]["images"]["front_base"].pop("floor", None)
    write(d, data)


plant("unclaimed-floor-fails", unclaimed_floor, "claimed by no image")


def ghost_floor(d):
    data = load(d)
    data["local_deploy"]["images"]["rails_floor"]["floor"] = "runtimes/nope/FLOOR.json"
    write(d, data)


plant("ghost-floor-fails", ghost_floor, "names a missing floor file")


# --- buildable -------------------------------------------------------------

def unbuildable(d):
    """index_digest false and no way to build it: neither pullable nor
    buildable, which is undeployable by construction.

    SYNTHESISES ITS SUBJECT instead of naming one. This popped
    stack.build.rails_floor, then stack.build.front_base, and broke both times
    -- once when the rails floor gained a registry digest and once when the
    front floor did. Both removals were correct; the plant was wrong to assume
    any particular image stays unpublished. stack.build is now empty, and a
    plant that needs an unbuilt image should make one."""
    data = load(d)
    data["local_deploy"]["images"]["planted_floor"] = {
        "name": "planted-floor",
        "digest": "sha256:" + ("a" * 64),
        "index_digest": False,
        "tag_for_humans": "planted-floor:local",
        "because": "planted: unpublished and with no way to build it",
    }
    write(d, data)


plant("unpublished-without-build-fails", unbuildable, "neither pulled nor built")


def build_tag_drift(d):
    data = load(d)
    data["local_deploy"]["images"]["planted_floor"] = {
        "name": "planted-floor",
        "digest": "sha256:" + ("a" * 64),
        "index_digest": False,
        "tag_for_humans": "planted-floor:local",
        "because": "planted",
    }
    data["stack"]["build"]["planted_floor"] = {
        "dockerfile": "runtimes/front-base/Dockerfile",
        "context": ".",
        "tag": "planted-floor:something-else",
    }
    write(d, data)


plant("build-tag-drift-fails", build_tag_drift, "disagrees with the image tag_for_humans")


def ghost_dockerfile(d):
    data = load(d)
    data["local_deploy"]["images"]["planted_floor"] = {
        "name": "planted-floor",
        "digest": "sha256:" + ("a" * 64),
        "index_digest": False,
        "tag_for_humans": "planted-floor:local",
        "because": "planted",
    }
    data["stack"]["build"]["planted_floor"] = {
        "dockerfile": "runtimes/nope/Dockerfile",
        "context": ".",
        "tag": "planted-floor:local",
    }
    write(d, data)


plant("ghost-dockerfile-fails", ghost_dockerfile, "dockerfile is missing")


# --- compose ---------------------------------------------------------------

def undeclared_pull(d):
    """compose pulls a digest the declaration never named."""
    p = os.path.join(d, "runtimes/mind-pod/app/extract/compose.yml")
    text = open(p, encoding="utf-8").read()
    old = "oxigraph/oxigraph@sha256:e68b3625743db4a4b18129a907ae36766f89bb6deeb8ab50d35685dbabe00b0e"
    open(p, "w", encoding="utf-8").write(
        text.replace(old, "oxigraph/oxigraph@sha256:" + ("c" * 64))
    )


plant("undeclared-pull-fails", undeclared_pull, "declares no image with digest")


def undriven_base(d):
    """The Dockerfile FROMs ${FRONT_BASE} but compose stops passing it, so the
    base silently becomes whatever the ARG default names.

    Strips whatever FRONT_BASE build-arg line is present rather than a literal
    one. The literal form stopped biting the moment the default changed from a
    local tag to a published ref -- silently, because this had no assert. Third
    instance of the same lesson today: a plant that hardcodes a value fails
    when the value is allowed to change, and it fails QUIETLY unless it checks
    that it bit."""
    p = os.path.join(d, "runtimes/mind-pod/app/extract/compose.yml")
    text = open(p, encoding="utf-8").read()
    out = "\n".join(
        l for l in text.splitlines() if not l.strip().startswith("FRONT_BASE:")
    ) + "\n"
    assert out != text, "plant did not bite: no FRONT_BASE build-arg line found"
    open(p, "w", encoding="utf-8").write(out)


plant("undriven-base-fails", undriven_base, "passes no FRONT_BASE build-arg")


def orphan_image_ref(d):
    """THE DEFECT THIS GATE FOUND IN THE WILD. rag in the canonical topology
    carried mind-pod:demo -- the extract file's tag -- while that file only
    builds mind-pod:latest, so `up rag` referenced an image it never builds.
    Planted back here so the fix cannot silently come undone."""
    p = os.path.join(d, "runtimes/mind-pod/docker-compose.yml")
    text = open(p, encoding="utf-8").read()
    out = text.replace("    image: mind-pod:latest\n", "    image: mind-pod:demo\n", 1)
    assert out != text, "plant did not bite: mind-pod:latest not found"
    open(p, "w", encoding="utf-8").write(out)


plant("orphan-image-ref-fails", orphan_image_ref, "which no service in this file builds")


def undriven_base_sibling(d):
    """THE SIBLING LIST MUST NOT BE INERT. The same defect planted in the
    canonical topology rather than the driven one: if this passes, siblings are
    being listed and not read, and the gate is narrower than it claims."""
    p = os.path.join(d, "runtimes/mind-pod/docker-compose.yml")
    text = open(p, encoding="utf-8").read()
    out = text.replace("        BASE: ${MIND_POD_BASE:-mind-pod-rails-base:latest}\n", "")
    assert out != text, "plant did not bite: the BASE arg line moved"
    open(p, "w", encoding="utf-8").write(out)


plant("undriven-base-in-sibling-fails", undriven_base_sibling, "passes no BASE build-arg")


def ghost_sibling(d):
    data = load(d)
    data["compose"]["siblings"].append("runtimes/nope/docker-compose.yml")
    write(d, data)


plant("ghost-sibling-fails", ghost_sibling, "compose.siblings does not exist")


def orphan_up_env(d):
    data = load(d)
    data["up_env"]["not_an_image"] = "NOPE"
    write(d, data)


plant("orphan-up-env-fails", orphan_up_env, "is not a local_deploy image")


def ghost_compose(d):
    data = load(d)
    data["compose"]["file"] = "runtimes/nope/compose.yml"
    write(d, data)


plant("ghost-compose-fails", ghost_compose, "compose.file does not exist")


def wrong_kind(d):
    data = load(d)
    data["kind"] = "cpcp-package"
    write(d, data)


plant("wrong-kind-fails", wrong_kind, "kind is")


print("plant | ok | detail")
print("------|----|--------")
bad = 0
for name, ok, detail in results:
    print("%s | %s | %s" % (name, str(ok).lower(), detail))
    if not ok:
        bad += 1
print("plant deploy-declaration: %s (%d/%d)" % ("OK" if not bad else "FAIL",
                                                len(results) - bad, len(results)))
raise SystemExit(1 if bad else 0)
