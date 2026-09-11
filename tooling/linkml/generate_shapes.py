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
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
REGISTER = ROOT / "tooling/linkml/sources.json"
VENV_BIN = ROOT / ".venv/bin"

# generator name -> (executable, comment prefix for the provenance header)
#
# `pydantic` is the in-process Python face PySparqlFun consumes
# (docs/architecture/SparqlFun.md). It earns a place here rather than being
# hand-written for the reason 0069 gives: a second hand-maintained schema is a
# second thing that drifts. Two properties were measured before adding it --
# gen-pydantic is byte-stable across runs and emits no `Generation date` line,
# so it needs neither the date strip nor the graph comparison SHACL needs.
#
# It also carries CLOSEDNESS, which the TypeScript face does not: the generated
# ConfiguredBaseModel sets `extra = "forbid"`, so a property the schema does not
# name is refused by the model the same way sh:closed refuses it on the wire.
# That is the opposite of bind_typescript_enums' problem and is why no
# post-processing hook exists for this target.
TARGETS = {
    "shacl": ("gen-shacl", "#"),
    "typescript": ("gen-typescript", "//"),
    "python": ("gen-python", "#"),
    "pydantic": ("gen-pydantic", "#"),
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


# Prefixes a strict SPARQL 1.1 processor requires you to declare and a lenient
# one pre-binds. rdflib binds these silently; Oxigraph does not, which is the
# whole reason this table exists.
WELL_KNOWN_PREFIXES = {
    "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    "rdfs": "http://www.w3.org/2000/01/rdf-schema#",
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "owl": "http://www.w3.org/2002/07/owl#",
    "sh": "http://www.w3.org/ns/shacl#",
    "skos": "http://www.w3.org/2004/02/skos/core#",
}

PREFIX_DECL = re.compile(r"^\s*PREFIX\s+([A-Za-z][\w.-]*)\s*:", re.MULTILINE | re.IGNORECASE)
PREFIX_USE = re.compile(r"(?<![<\w:])([A-Za-z][\w.-]*):[A-Za-z_]")


def declare_missing_prefixes(query: str) -> tuple[str, list[str]]:
    """Declare prefixes the query uses but does not bind.

    `gen-sparql` emits `?subject rdf:type <Class>` while declaring only the
    schema's own prefixes. rdflib pre-binds `rdf:` so the query parses there;
    Oxigraph does not, and the store answers HTTP 400 "Prefix not found". A
    query that cannot run is the worst kind of pseudo validation -- it looks
    like a check and never executes.

    Returns (query, unfixable) where `unfixable` names prefixes used, not
    declared, and not well-known. Those are a real defect and must not be
    papered over with a guessed namespace.
    """
    declared = {m.group(1) for m in PREFIX_DECL.finditer(query)}
    used = {m.group(1) for m in PREFIX_USE.finditer(query)}
    missing = sorted(used - declared - {"http", "https", "urn"})

    additions, unfixable = [], []
    for prefix in missing:
        if prefix in WELL_KNOWN_PREFIXES:
            additions.append(f"PREFIX {prefix}: <{WELL_KNOWN_PREFIXES[prefix]}>")
        else:
            unfixable.append(prefix)

    if additions:
        query = "\n".join(additions) + "\n" + query
    return query, unfixable


def sparql_accepted_by_oxigraph(query: str) -> str | None:
    """None when the real engine accepts the query, else the parse error.

    pyoxigraph is Oxigraph, so this is the store's own parser rather than an
    approximation of it.
    """
    try:
        import pyoxigraph  # noqa: PLC0415

        pyoxigraph.Store().query(query)
        return None
    except ImportError:
        return "pyoxigraph not installed -- an unverifiable query is not a passing one"
    except Exception as exc:
        return str(exc).splitlines()[0][:180]


def enum_slots(schema: Path) -> dict[str, dict[str, str]]:
    """{ClassName: {slot_name: EnumName}} for every enum-ranged slot."""
    try:
        from linkml_runtime.utils.schemaview import SchemaView  # noqa: PLC0415

        view = SchemaView(str(schema))
        enums = set(view.all_enums())
        out: dict[str, dict[str, str]] = {}
        for class_name in view.all_classes():
            try:
                slots = view.class_induced_slots(class_name)
            except Exception:
                continue
            hits = {s.name: s.range for s in slots if getattr(s, "range", None) in enums}
            if hits:
                out[class_name] = hits
        return out
    except Exception:
        return {}


def bind_typescript_enums(body: str, mapping: dict[str, dict[str, str]]) -> str:
    """Type enum-ranged fields as their enum instead of as `string`.

    gen-typescript emits the enum and then types the slot `string`, so the
    closed vocabulary SHACL enforces as sh:in is unenforced on the browser
    side -- a consumer reads a declared enum and gets no constraint from it.
    That is pseudo validation in the client, and the artifact is ours to fix
    even though the generator is not.

    Rewrites only inside the matching `export interface` block, so a slot name
    shared by two classes cannot be retyped from the wrong one.
    """
    if not mapping:
        return body

    lines = body.splitlines()
    current: str | None = None
    out: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("export interface "):
            current = stripped.split()[2]
        elif stripped == "}":
            current = None
        elif current and current in mapping:
            for slot, enum_name in mapping[current].items():
                for opt in ("?", ""):
                    needle = f"{slot}{opt}: string"
                    if stripped.startswith(needle):
                        line = line.replace(needle, f"{slot}{opt}: {enum_name}", 1)
                        break
        out.append(line)
    return "\n".join(out)


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


def canonical_turtle(body: str) -> str:
    """Serialise the SHACL graph deterministically.

    gen-shacl orders blank-node property shapes differently per run, so the
    committed artifact changed on every regeneration while meaning the same
    thing. The gate tolerated that by comparing graphs, but every regeneration
    still churned the diff and the manifest digest -- noise that trains people
    to skim exactly the file they should read.

    Canonicalising relabels blank nodes deterministically, which makes the
    bytes stable. It costs some prefix reuse in the output; a stable artifact
    is worth more than a prettier unstable one.
    """
    try:
        from rdflib import Graph  # noqa: PLC0415
        from rdflib.compare import to_canonical_graph  # noqa: PLC0415

        src = Graph().parse(data=body, format="turtle")
        canonical = to_canonical_graph(src)

        # Carry the prefixes across. to_canonical_graph returns a read-only
        # aggregate with no namespace bindings, and serialising that emits
        # <urn:mm:vocab/pod#Note> where every hand-written shape in this repo
        # emits pod:Note. The governance tooling extracts shape names by
        # pattern, and a full IRI parsed as a prefixed name yields "Note>" --
        # a shape that then matches nothing it is checked against.
        out = Graph()
        for prefix, namespace in src.namespaces():
            out.bind(prefix, namespace)
        for triple in canonical:
            out.add(triple)
        return out.serialize(format="turtle")
    except Exception:
        return body


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


def generate_sparql(schema: Path, out_dir: Path, header: str, check_only: bool) -> list[str]:
    """Generate the validation queries, declare their prefixes, and prove they run.

    `gen-sparql` writes a directory rather than stdout, so this does not fit
    the one-artifact-per-target loop. Every query is checked against
    pyoxigraph -- the engine the pod actually runs -- because parsing under
    rdflib proves nothing about whether the store will accept it.
    """
    problems: list[str] = []
    binary = VENV_BIN / "gen-sparql"
    if not binary.is_file():
        return [f"gen-sparql not found at {binary}"]

    with tempfile.TemporaryDirectory() as tmp:
        proc = subprocess.run(
            [str(binary), "-d", tmp, str(schema)], capture_output=True, text=True, timeout=300
        )
        if proc.returncode != 0:
            return [f"gen-sparql exited {proc.returncode}: {proc.stderr.strip()[:300]}"]

        produced = sorted(Path(tmp).glob("*.rq"))
        if not produced:
            return ["gen-sparql produced no queries -- an empty population is not a pass"]

        rendered: dict[str, str] = {}
        for query_file in produced:
            body, unfixable = declare_missing_prefixes(query_file.read_text(encoding="utf-8"))
            if unfixable:
                problems.append(
                    f"{query_file.name}: uses undeclared prefix(es) {unfixable} that are not "
                    f"well-known. Guessing a namespace would be worse than failing."
                )
                continue

            error = sparql_accepted_by_oxigraph(body)
            if error:
                problems.append(f"{query_file.name}: Oxigraph rejects this query -- {error}")
                continue

            rendered[query_file.name] = header + body.strip() + "\n"

    if check_only:
        existing = {p.name for p in out_dir.glob("*.rq")} if out_dir.is_dir() else set()
        for name, text in rendered.items():
            path = out_dir / name
            if not path.is_file():
                problems.append(f"missing generated query {path.relative_to(ROOT)}")
            elif path.read_text(encoding="utf-8") != text:
                problems.append(f"{path.relative_to(ROOT)} is out of date -- regenerate")
        for stale in sorted(existing - set(rendered)):
            problems.append(f"stale generated query {out_dir.name}/{stale} -- the schema no longer produces it")
    else:
        if out_dir.is_dir():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        for name, text in rendered.items():
            (out_dir / name).write_text(text, encoding="utf-8")

    return problems


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

            if target == "sparql":
                out_dir = ROOT / artifact_rel
                header = provenance("#", schema_rel, digest, "gen-sparql", version)
                found = generate_sparql(schema, out_dir, header, check_only)
                problems.extend(f"{schema_rel} -> sparql: {p}" for p in found)
                if not found and not check_only:
                    written += 1
                continue

            if target not in TARGETS:
                problems.append(f"{schema_rel}: unknown target {target!r}")
                continue

            exe, comment = TARGETS[target]
            ok, out = run_generator(exe, schema)
            if not ok:
                problems.append(f"{schema_rel} -> {target}: {out}")
                continue

            fresh = strip_generation_date(out).strip() + "\n"
            if target == "typescript":
                fresh = bind_typescript_enums(fresh, enum_slots(schema))
            elif target == "shacl":
                fresh = canonical_turtle(fresh)
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
            elif artifact.is_dir():
                # A directory target (sparql) publishes every file it holds.
                # Recording only the directory name would put these artifacts
                # outside the publication promise -- a consumer could not tell
                # whether the queries it was handed are the ones this schema
                # produced.
                row["artifacts"][target] = {
                    "path": artifact_rel,
                    "files": {
                        f.name: sha256(f.read_text(encoding="utf-8"))
                        for f in sorted(artifact.iterdir())
                        if f.is_file()
                    },
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
