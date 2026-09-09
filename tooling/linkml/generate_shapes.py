#!/usr/bin/env python3
"""Reify the shape container's LinkML sources into SHACL, TypeScript and Python.

DEV ONLY. This is the "morph" half of the dev/prod split: shapes are morphed
here and only read in production. Nothing under runtimes/ runs this, no image
installs linkml, and no request path generates a shape. The artifacts this
writes are committed, and prod reads those bytes.

  .venv/bin/python tooling/linkml/generate_shapes.py          # write artifacts
  .venv/bin/python tooling/linkml/generate_shapes.py --check  # verify only

--check is what tooling/linkml/check_shape_artifacts.py calls, so the generator
and the gate cannot disagree about what "in sync" means -- one implementation,
two entry points.

FAILS CLOSED: an empty source register is an error, not a pass. A generator
that finds nothing to do reports success otherwise, which reads as coverage it
has not got.

## Why the comparison is not a byte comparison

gen-shacl is byte-unstable and graph-stable. rdflib serialises blank-node
property shapes in a different order per run, so two runs over an unchanged
schema differ textually while being RDF-isomorphic. Committing a canonical
N-Triples blob would fix that and cost the reader a file they can read, and
ROLE=shape serves these bytes to humans as well as machines. So: artifacts are
committed as readable Turtle, and SHACL is compared as a GRAPH.

gen-python and gen-typescript are byte-stable once the `Generation date` line
is dropped, which is done at write time rather than at compare time -- a
committed artifact that changes every time someone regenerates it is noise in
every diff that touches it.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
REGISTER = ROOT / "tooling/linkml/sources.json"
VENV_BIN = ROOT / ".venv/bin"

# generator name -> (executable, comment prefix for the provenance header)
TARGETS = {
    "shacl": ("gen-shacl", "#"),
    "typescript": ("gen-typescript", "//"),
    "python": ("gen-python", "#"),
}

DATE_MARKER = "Generation date:"


def fail(msg: str) -> int:
    print("FAIL: %s" % msg, file=sys.stderr)
    return 1


def linkml_version() -> str:
    """The installed generator version, which belongs in every artifact header.

    linkml does not expose __version__, so this reads installed distribution
    metadata. It matters because generator output moves with the generator: an
    artifact that does not name the version it came from cannot be told apart
    from one the schema changed.
    """
    try:
        from importlib.metadata import version  # noqa: PLC0415

        return version("linkml")
    except Exception:  # pragma: no cover - reported, not raised
        return "unknown"


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def strip_generation_date(body: str) -> str:
    """Drop the one line that changes without the schema changing."""
    return "\n".join(line for line in body.splitlines() if DATE_MARKER not in line)


def provenance(comment: str, schema_rel: str, digest: str, generator: str, version: str) -> str:
    return "\n".join(
        [
            f"{comment} GENERATED from {schema_rel}. Do not hand-edit.",
            f"{comment}",
            f"{comment} generator:    {generator} (linkml {version})",
            f"{comment} source-sha256: {digest}",
            f"{comment}",
            f"{comment} Regenerate with tooling/linkml/generate_shapes.py. The shape container",
            f"{comment} owns this file; editing it here makes the artifact stop tracing to its",
            f"{comment} source, which check_shape_artifacts.py fails on.",
            "",
            "",
        ]
    )


def run_generator(exe: str, schema: Path) -> tuple[bool, str]:
    binary = VENV_BIN / exe
    if not binary.is_file():
        return False, f"{exe} not found at {binary} -- pip install -r tooling/linkml/requirements.txt"
    proc = subprocess.run([str(binary), str(schema)], capture_output=True, text=True, timeout=300)
    if proc.returncode != 0:
        return False, f"{exe} exited {proc.returncode}: {proc.stderr.strip()[:400]}"
    if not proc.stdout.strip():
        return False, f"{exe} produced no output"
    return True, proc.stdout


def graphs_match(a: str, b: str) -> bool:
    """SHACL equality is graph isomorphism, not byte equality. See the docstring."""
    try:
        from rdflib import Graph  # noqa: PLC0415
        from rdflib.compare import to_isomorphic  # noqa: PLC0415

        ga = Graph().parse(data=a, format="turtle")
        gb = Graph().parse(data=b, format="turtle")
        return to_isomorphic(ga) == to_isomorphic(gb)
    except Exception:
        return False


# No header-stripping helper on purpose. The expected artifact is header +
# body, both deterministic, so check mode rebuilds the whole file and compares
# that -- there is nothing to strip and therefore nothing to get subtly wrong.
# For SHACL the comparison is graph isomorphism over the whole file, and Turtle
# comments are not triples, so the header is invisible to it either way.


def main() -> int:
    check_only = "--check" in sys.argv

    if not REGISTER.is_file():
        return fail(f"no source register at {REGISTER}")
    register = json.loads(REGISTER.read_text(encoding="utf-8"))
    sources = register.get("sources", [])
    if not sources:
        return fail("source register names no schemas -- an empty population is not a pass")

    version = linkml_version()
    problems: list[str] = []
    written = 0
    examined = 0

    for entry in sources:
        schema_rel = entry["schema"]
        schema = ROOT / schema_rel
        if not schema.is_file():
            problems.append(f"missing schema {schema_rel}")
            continue

        digest = sha256(schema.read_text(encoding="utf-8"))

        for target, artifact_rel in entry.get("artifacts", {}).items():
            examined += 1
            if target not in TARGETS:
                problems.append(f"{schema_rel}: unknown target {target!r}")
                continue

            exe, comment = TARGETS[target]
            ok, out = run_generator(exe, schema)
            if not ok:
                problems.append(f"{schema_rel} -> {target}: {out}")
                continue

            fresh = strip_generation_date(out).strip() + "\n"
            artifact = ROOT / artifact_rel
            header = provenance(comment, schema_rel, digest, exe, version)

            if check_only:
                if not artifact.is_file():
                    problems.append(f"missing artifact {artifact_rel} (schema {schema_rel})")
                    continue
                committed = artifact.read_text(encoding="utf-8")
                if f"source-sha256: {digest}" not in committed:
                    problems.append(
                        f"{artifact_rel} does not trace to {schema_rel}: source-sha256 header "
                        f"is stale or absent (schema is now {digest[:12]})"
                    )
                    continue
                expected = header + fresh
                same = graphs_match(committed, expected) if target == "shacl" else committed == expected
                if not same:
                    problems.append(f"{artifact_rel} is out of date with {schema_rel} -- regenerate")
            else:
                artifact.parent.mkdir(parents=True, exist_ok=True)
                artifact.write_text(header + fresh, encoding="utf-8")
                written += 1

    # The publishable index. A standards document publishes the LinkML SOURCE
    # and the generated artifacts together, and this is what ties them: one
    # entry per schema, naming the source, its digest, every artifact and its
    # digest, and the generator version that produced them. A downstream repo
    # reads this file to know what it is consuming and whether it still
    # matches; without it, "here are some shapes" is not a publication.
    manifest_path = ROOT / "tooling/linkml/generated/MANIFEST.json"
    manifest = {
        "_why": (
            "Published index for the CPCP shape ecosystem. Source of truth is the LinkML "
            "schema; the artifacts are reified from it. Consumers verify source_sha256 "
            "against the schema they were given and artifact sha256 against the bytes they "
            "read. Generated by tooling/linkml/generate_shapes.py -- do not hand-edit."
        ),
        "generator": {"linkml": version},
        "schemas": [],
    }
    for entry in sources:
        schema = ROOT / entry["schema"]
        if not schema.is_file():
            continue
        row = {
            "schema": entry["schema"],
            "source_sha256": sha256(schema.read_text(encoding="utf-8")),
            "why": entry.get("why", ""),
            "artifacts": {},
        }
        for target, artifact_rel in entry.get("artifacts", {}).items():
            artifact = ROOT / artifact_rel
            if artifact.is_file():
                row["artifacts"][target] = {
                    "path": artifact_rel,
                    "sha256": sha256(artifact.read_text(encoding="utf-8")),
                }
        manifest["schemas"].append(row)

    rendered = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    if check_only:
        if not manifest_path.is_file():
            problems.append("missing published manifest tooling/linkml/generated/MANIFEST.json")
        elif manifest_path.read_text(encoding="utf-8") != rendered:
            problems.append("published manifest is out of date -- regenerate")
    else:
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(rendered, encoding="utf-8")

    verb = "checked" if check_only else "wrote"
    print(f"linkml shapes: {verb} {examined} artifact(s) from {len(sources)} schema(s), linkml {version}")
    if problems:
        for p in problems:
            print(f"  FAIL {p}", file=sys.stderr)
        print("linkml shapes: FAIL (%d)" % len(problems), file=sys.stderr)
        return 1
    if not check_only:
        print(f"linkml shapes: wrote {written}")
    print("linkml shapes: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
