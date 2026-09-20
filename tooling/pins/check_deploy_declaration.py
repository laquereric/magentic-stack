#!/usr/bin/env python3
"""`.cpcp/deploy.json` is held against the tree it points at.

DEPLOY.md calls this file "the line you change for deploy identity", and until
this gate existed it was the one declaration in the repo with nothing behind it
-- while published_images.json, base_image_digests.json, the four cpcp_registry
pin sites and the doc container-counts all had a checker. Two defects lived in
it for weeks as a direct result:

  front-base was declared NOWHERE, so `bin/docker-containers up` preflighted
  four images, reached the front service, and fell through to Docker Hub for
  library/front-base -- the failure boundary-conformance.yml already records
  for rails-base, one image over.

  hooks.before_up named runtimes/mind-pod/app/bin/prepare for three weeks
  after e215ea1 deleted it on purpose. run_hooks warned to stderr and carried
  on, so the only sign was a line scrolling past during a docker build.

Both are now rules here. What this holds:

  STRUCTURE   kind/version, every image digest is a real OCI digest, every
              image carries a name and a because.
  FLOOR       an image may name its FLOOR file; if it does, the digest and the
              human tag must agree with it. Held BOTH WAYS: every FLOOR file in
              the tree must be claimed by exactly one image, so adding a floor
              without declaring it fails.
  BUILDABLE   an image with `index_digest: false` cannot be pulled by anyone,
              so it MUST have a stack.build entry. This is the front-base rule
              stated exactly: undeclared-and-unbuildable is the defect.
  COMPOSE     every image a held compose file PULLS is declared here with the
              same digest; every image it BUILDS whose Dockerfile does
              `FROM ${VAR}` must have that base driven by up_env, not by the
              Dockerfile's ARG default.
  PATHS       compose files, chdir, stack.build dockerfiles and contexts, and
              every declared hook, all exist.

POPULATION BOUNDARY, STATED RATHER THAN IMPLIED. The compose files held are
`compose.file` (the one bin/docker-containers drives) plus `compose.siblings`
-- read from the declaration as data, never as a path literal here. Siblings
exist because the front-base defect was present in BOTH compose files, so
holding only the driven one would have left the other free to regress in
exactly the way this gate exists to stop. A compose file in neither list is
outside this population and is covered, if at all, by tooling/compose/*.

Keys beginning with `_` are prose (`_why`, `_removed`, `_context_why`) and are
skipped everywhere. Empty CHECK_ROOT fails. 0 images examined is not a pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

DEPLOY_REL = Path(".cpcp") / "deploy.json"
KIND = "cpcp-deploy"
OCI = re.compile(r"\Asha256:[0-9a-f]{64}\Z")
PLACEMENTS = ("local_deploy", "remote_deploy")


def fail(msg: str) -> int:
    print("DEPLOY-DECLARATION FAIL: %s" % msg, file=sys.stderr)
    return 1


def root_from_env() -> Path | None:
    raw = os.environ.get("CHECK_ROOT")
    if raw is None:
        return Path(__file__).resolve().parents[2]
    if not raw.strip():
        return None
    return Path(raw)


def real(d):
    """Declaration entries only -- `_`-prefixed keys are prose."""
    if not isinstance(d, dict):
        return {}
    return {k: v for k, v in d.items() if not str(k).startswith("_")}


# --- compose reading -------------------------------------------------------
# Hand-rolled, like every sibling checker. No yaml import anywhere in tooling/,
# and this gate must run under bin/sweep's venv as well as a bare CI python.

def services(text: str):
    """(name, block) for each top-level service."""
    m = re.search(r"^services:\s*$", text, re.M)
    if not m:
        return []
    body = text[m.end():]
    nxt = re.search(r"^[A-Za-z]", body, re.M)
    end = nxt.start() if nxt else len(body)
    # Names must be filtered by `end`, not just used to slice up to it. A
    # volume with a nested block (milvus_embed_etcd) matches the same
    # two-space pattern, so an unfiltered scan enumerated it as a 15th
    # service. It has no image and no build, so every rule skipped it and the
    # gate still passed -- a green report over a population one larger than
    # the file has. That is the shape of miscount this repo refuses.
    names = [(mm.start(), mm.group(1))
             for mm in re.finditer(r"^  ([A-Za-z0-9_-]+):\s*$", body, re.M)
             if mm.start() < end]
    out = []
    for i, (start, name) in enumerate(names):
        stop = names[i + 1][0] if i + 1 < len(names) else end
        out.append((name, body[start:stop]))
    return out


def image_of(block: str) -> str:
    m = re.search(r"^\s{4}image:\s*(\S+)\s*$", block, re.M)
    return m.group(1) if m else ""


def build_of(block: str):
    """{'context':…, 'dockerfile':…, 'args': {ARG: ENVVAR}} or None.

    Both spellings appear in this repo's compose files and both must be read:
    inline flow (`build: { context: ../../mind, dockerfile: Dockerfile }`) and
    the indented block form with an args map.
    """
    inline = re.search(r"^\s{4}build:\s*\{(.+?)\}\s*$", block, re.M | re.S)
    if inline:
        body = inline.group(1)
        return {
            "context": _field(body, "context"),
            "dockerfile": _field(body, "dockerfile"),
            "args": {},
        }
    m = re.search(r"^\s{4}build:\s*$", block, re.M)
    if not m:
        return None
    rest = block[m.end():]
    stop = re.search(r"^\s{4}\S", rest, re.M)
    body = rest[: stop.start()] if stop else rest
    args = {}
    am = re.search(r"^\s{6}args:\s*$", body, re.M)
    if am:
        arest = body[am.end():]
        astop = re.search(r"^\s{0,6}\S", arest, re.M)
        abody = arest[: astop.start()] if astop else arest
        for mm in re.finditer(
            r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*\$\{([A-Za-z_][A-Za-z0-9_]*)", abody, re.M
        ):
            args[mm.group(1)] = mm.group(2)
    return {
        "context": _field(body, "context"),
        "dockerfile": _field(body, "dockerfile"),
        "args": args,
    }


def _field(body: str, key: str) -> str:
    m = re.search(r"%s\s*:\s*([^,\n}]+)" % key, body)
    return m.group(1).strip() if m else ""


def split_ref(ref: str):
    """(name, digest) for an image reference. A tag is never identity here."""
    digest = ""
    if "@" in ref:
        ref, digest = ref.split("@", 1)
    name = ref
    if ":" in ref.rsplit("/", 1)[-1]:
        name = ref.rsplit(":", 1)[0]
    return name, digest


FROM_VAR = re.compile(r"^FROM\s+\$\{([A-Za-z_][A-Za-z0-9_]*)\}", re.M)


def main() -> int:
    root = root_from_env()
    if root is None:
        return fail("empty CHECK_ROOT")
    if not root.is_dir():
        return fail("CHECK_ROOT is not a directory: %s" % root)

    path = root / DEPLOY_REL
    if not path.is_file():
        return fail("missing declaration %s" % path)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return fail("%s does not parse: %s" % (path, exc))
    if not isinstance(data, dict):
        return fail("%s is not a JSON object" % path)

    errors = []
    if data.get("kind") != KIND:
        errors.append("kind is %r, want %r" % (data.get("kind"), KIND))
    if not isinstance(data.get("version"), int):
        errors.append("version must be an integer")

    images = {}
    for placement in PLACEMENTS:
        slot = data.get(placement)
        if not isinstance(slot, dict):
            continue
        for key, image in real(slot.get("images")).items():
            if not isinstance(image, dict):
                errors.append("%s.images.%s is not an object" % (placement, key))
                continue
            images[(placement, key)] = image

    if not images:
        return fail("%s declares no images under %s" % (path, " or ".join(PLACEMENTS)))

    local = {k: v for (p, k), v in images.items() if p == "local_deploy"}

    # --- STRUCTURE ---------------------------------------------------------
    for (placement, key), image in sorted(images.items()):
        where = "%s.images.%s" % (placement, key)
        digest = str(image.get("digest", ""))
        if not OCI.match(digest):
            if ":" in digest and not digest.startswith("sha256:"):
                errors.append("%s digest is %r; a tag is not a pin" % (where, digest))
            else:
                errors.append("%s malformed digest %r" % (where, digest))
        if not str(image.get("name") or "").strip():
            errors.append("%s has no name" % where)
        if not str(image.get("because") or "").strip():
            errors.append("%s has no because" % where)

    # --- FLOOR, both ways --------------------------------------------------
    claimed = {}
    for (placement, key), image in sorted(images.items()):
        rel = str(image.get("floor") or "").strip()
        if not rel:
            continue
        where = "%s.images.%s" % (placement, key)
        fp = root / rel
        if not fp.is_file():
            errors.append("%s names a missing floor file: %s" % (where, rel))
            continue
        if rel in claimed:
            errors.append("floor %s is claimed by both %s and %s" % (rel, claimed[rel], where))
        claimed[rel] = where
        try:
            floor = (json.loads(fp.read_text(encoding="utf-8")) or {}).get("floor") or {}
        except (OSError, json.JSONDecodeError) as exc:
            errors.append("%s does not parse: %s" % (rel, exc))
            continue
        if str(floor.get("digest", "")) != str(image.get("digest", "")):
            errors.append(
                "%s digest %s disagrees with %s floor.digest %s"
                % (where, image.get("digest"), rel, floor.get("digest"))
            )
        dt, it = floor.get("tag_for_humans"), image.get("tag_for_humans")
        if dt and it and str(dt) != str(it):
            errors.append(
                "%s tag_for_humans %r disagrees with %s %r" % (where, it, rel, dt)
            )

    runtimes = root / "runtimes"
    if runtimes.is_dir():
        for fp in sorted(runtimes.rglob("FLOOR*.json")):
            rel = fp.relative_to(root).as_posix()
            if rel not in claimed:
                errors.append(
                    "floor file %s is claimed by no image; a declared floor that "
                    "the deploy declaration does not name is a floor nothing pins" % rel
                )

    # --- BUILDABLE: the front-base rule ------------------------------------
    build = real((data.get("stack") or {}).get("build"))
    for key, image in sorted(local.items()):
        if image.get("index_digest") is not False:
            continue
        if key not in build:
            errors.append(
                "local_deploy.images.%s is unpublished (index_digest: false) and has no "
                "stack.build entry, so it can be neither pulled nor built -- this is the "
                "state front-base was in" % key
            )

    for key, spec in sorted(build.items()):
        if key not in local:
            errors.append("stack.build.%s is not a local_deploy image" % key)
            continue
        df = str(spec.get("dockerfile") or "")
        if not df or not (root / df).is_file():
            errors.append("stack.build.%s dockerfile is missing: %r" % (key, df))
        ctx = str(spec.get("context") or ".")
        if not (root / ctx).is_dir():
            errors.append("stack.build.%s context is not a directory: %r" % (key, ctx))
        tag, want = spec.get("tag"), local[key].get("tag_for_humans")
        if tag and want and str(tag) != str(want):
            errors.append(
                "stack.build.%s tag %r disagrees with the image tag_for_humans %r"
                % (key, tag, want)
            )

    up_env = real(data.get("up_env"))
    for key in sorted(up_env):
        if key not in local:
            errors.append("up_env.%s is not a local_deploy image" % key)

    # --- HOOKS -------------------------------------------------------------
    for name, rels in sorted(real(data.get("hooks")).items()):
        if not isinstance(rels, list):
            continue
        for rel in rels:
            if not (root / str(rel)).is_file():
                errors.append("hooks.%s names a missing file: %s" % (name, rel))

    # --- COMPOSE -----------------------------------------------------------
    compose = data.get("compose") or {}
    crel = str(compose.get("file") or "")
    siblings = [str(s) for s in (compose.get("siblings") or []) if str(s).strip()]
    examined_services = 0

    if not crel:
        errors.append("compose.file is not declared")
    else:
        chdir = str(compose.get("chdir") or "")
        if chdir and not (root / chdir).is_dir():
            errors.append("compose.chdir is not a directory: %s" % chdir)

    by_digest = {str(v.get("digest")): k for k, v in local.items()}
    driven = set(up_env.values())

    # The driven file and every declared sibling get the same invariants. Only
    # the first is what `docker compose` is pointed at; the rest describe the
    # same pod and may not drift into a claim the declaration does not make.
    for rel, role in ([(crel, "compose.file")] if crel else []) + [
        (s, "compose.siblings") for s in siblings
    ]:
        cpath = root / rel
        if not cpath.is_file():
            errors.append("%s does not exist: %s" % (role, rel))
            continue

        text = cpath.read_text(encoding="utf-8", errors="replace")
        blocks = services(text)
        if not blocks:
            errors.append("%s declares no services" % rel)
        built_images = {
            image_of(b) for _, b in blocks if build_of(b) is not None and image_of(b)
        }

        for name, block in blocks:
            examined_services += 1
            ref = image_of(block)
            spec = build_of(block)
            at = "%s service %s" % (rel, name)

            if spec is None:
                # Pulled -- unless another service in this file builds that
                # exact image. One image run as many roles is the pod's shape
                # (ADR 0056), not an undeclared pull.
                if ref and ref not in built_images:
                    iname, idigest = split_ref(ref)
                    if not idigest:
                        # Two different faults share this shape, so say which.
                        # A bare tag that no service here builds is usually a
                        # reference copied from the sibling file (rag carried
                        # mind-pod:demo in the canonical topology, which only
                        # builds mind-pod:latest); a bare tag on a genuinely
                        # third-party image is an unpinned pull.
                        kin = sorted(built_images)
                        errors.append(
                            "%s references %s, which no service in this file builds and "
                            "which carries no digest to pull by%s"
                            % (at, ref, (" -- this file builds %s" % ", ".join(kin)) if kin else "")
                        )
                    elif idigest not in by_digest:
                        errors.append(
                            "%s pulls %s but local_deploy.images declares no image "
                            "with digest %s" % (at, ref, idigest)
                        )
                    else:
                        declared = local[by_digest[idigest]]
                        if str(declared.get("name")) != iname:
                            errors.append(
                                "%s pulls %s but the declaration calls that digest %r"
                                % (at, iname, declared.get("name"))
                            )
                continue

            # Built. If its Dockerfile FROMs a build-arg, the base must be
            # driven by the declaration rather than by the ARG default.
            df = spec.get("dockerfile") or "Dockerfile"
            ctx = spec.get("context") or "."
            dfp = (cpath.parent / ctx / df).resolve()
            if not dfp.is_file():
                errors.append("%s builds %s which does not exist" % (at, dfp))
                continue
            dtext = dfp.read_text(encoding="utf-8", errors="replace")
            for var in FROM_VAR.findall(dtext):
                env = spec["args"].get(var)
                if env is None:
                    errors.append(
                        "%s builds a Dockerfile whose FROM is ${%s}, but compose passes "
                        "no %s build-arg, so the base is whatever the Dockerfile ARG "
                        "default happens to name" % (at, var, var)
                    )
                elif env not in driven:
                    errors.append(
                        "%s drives its base from ${%s}, which no up_env entry sets -- so "
                        "no declared image supplies it. front-base was exactly this"
                        % (at, env)
                    )

    ok, _ = emit_population(len(images), skipped=0, skipped_reason="")
    print("compose files held: %d (%s)" % (
        (1 if crel else 0) + len(siblings),
        ", ".join(([crel] if crel else []) + siblings) or "none"))
    print("services examined: %d" % examined_services)
    if not ok:
        return 1
    if errors:
        print("DEPLOY-DECLARATION FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print(
        "deploy declaration: OK (%d images, %d floors claimed, %d built, %d hooks)"
        % (
            len(images),
            len(claimed),
            len(build),
            sum(len(v) for v in real(data.get("hooks")).values() if isinstance(v, list)),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
