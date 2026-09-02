#!/usr/bin/env python3
"""Fail when ProfileCatalog Entry#shape_iri is not the TTL NodeShape IRI.

Gap 98. check_shape_binding / check_shape_resolution key by local name.
check_shape_drift canons sh:path to a local token. check_iri_namespaces
baselines catalog literals and @prefix IRIs separately, so a catalog IRI
and a TTL NodeShape IRI can still diverge while each matches its own
baseline. This checker JOINS them: the full expanded IRI on the catalog
entry must equal a sh:NodeShape IRI in the TTL file that entry resolves.

A catalog IRI change that keeps the local name fails. A @prefix change
that keeps local names fails. Empty CHECK_ROOT fails. 0 examined is
not a pass.

Does not rename any IRI. Does not edit TTL or the catalog.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

CATALOG = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile_catalog.rb")
P9_VOCAB = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/vocabulary.rb")
P11_VOCAB = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile11/vocabulary.rb")

GEM_ROOT = {
    "APP": Path("gems/shapes-application"),
    "L8": Path("gems/shapes-level-8"),
}

# Literal SHAPE_MAP / L8_PROTOCOL_MAP rows.
MAP_RE = re.compile(
    r'"((?:P\d+::)[^"]+Shape)"\s*=>\s*\[(APP|L8),\s*'
    r'"#\{(?:APP_MIND|L8_BUNDLES)\}/([^"]+\.ttl)",\s*"[^"]+",\s*'
    r'"(https://[^"]+)"'
)

# p9_operation_shapes / p11_operation_shapes must construct IRI as VOCAB_IRI+local.
GEN_RE = re.compile(
    r"def self\.(p9_operation_shapes|p11_operation_shapes)\b.*?"
    r'\[name, \[(APP|L8), "#\{(?:APP_MIND|L8_BUNDLES)\}/([^"]+\.ttl)", '
    r'"(P\d+)", "#\{vocab::VOCAB_IRI\}#\{local\}"\]',
    re.S,
)

VOCAB_IRI_RE = re.compile(r"""VOCAB_IRI\s*=\s*["'](https://[^"']+)["']""")
OP_SHAPE_RE = re.compile(
    r"""(?:request_shape|response_shape):\s*["']((?:P\d+::)[^"']+Shape)["']"""
)
PREFIX_RE = re.compile(r"^@prefix\s+([A-Za-z0-9_]+):\s*<([^>]+)>", re.M)
NODESHAPE_RE = re.compile(r"(\S+)\s+a\s+sh:NodeShape\b")


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


def local_of(iri: str) -> str:
    return iri.rstrip("/").split("#")[-1].split("/")[-1]


def ttl_rel(gem_token: str, filename: str) -> Path:
    if gem_token == "APP":
        return GEM_ROOT["APP"] / "contracts/mind-pod" / filename
    if gem_token == "L8":
        return GEM_ROOT["L8"] / "bundles" / filename
    raise ValueError("unknown gem token %s" % gem_token)


def parse_nodeshapes(text: str):
    prefixes = {m.group(1): m.group(2) for m in PREFIX_RE.finditer(text)}
    out = []
    for n, line in enumerate(text.splitlines(), 1):
        m = NODESHAPE_RE.search(line)
        if not m:
            continue
        token = m.group(1)
        if token.startswith("<") and token.endswith(">"):
            iri = token[1:-1]
        elif ":" in token:
            pref, local = token.split(":", 1)
            base = prefixes.get(pref)
            if base is None:
                iri = token
            else:
                iri = base + local
        else:
            iri = token
        out.append({"iri": iri, "local": local_of(iri), "line": n, "token": token})
    return out


def parse_vocab_iris(text: str):
    vm = VOCAB_IRI_RE.search(text)
    if not vm:
        return None, []
    vocab_iri = vm.group(1)
    names = []
    seen = set()
    for m in OP_SHAPE_RE.finditer(text):
        name = m.group(1)
        if name in seen:
            continue
        seen.add(name)
        names.append(name)
    return vocab_iri, names


def catalog_entries(root: Path, errors: list):
    path = root / CATALOG
    if not path.is_file():
        errors.append("missing %s" % CATALOG.as_posix())
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    entries = []
    seen = {}

    def add(shape, gem_token, filename, iri, source):
        key = shape
        rec = {
            "shape": shape,
            "gem": gem_token,
            "file": ttl_rel(gem_token, filename).as_posix(),
            "iri": iri,
            "source": source,
        }
        if key in seen:
            prev = seen[key]
            if prev["iri"] != iri or prev["file"] != rec["file"]:
                errors.append(
                    "duplicate catalog key %s (%s %s vs %s %s)"
                    % (key, prev["iri"], prev["file"], iri, rec["file"])
                )
            return
        seen[key] = rec
        entries.append(rec)

    for m in MAP_RE.finditer(text):
        add(m.group(1), m.group(2), m.group(3), m.group(4), "literal")

    gens = {m.group(1): m for m in GEN_RE.finditer(text)}
    expected_gens = {
        "p9_operation_shapes": (P9_VOCAB, "P9"),
        "p11_operation_shapes": (P11_VOCAB, "P11"),
    }
    for method, (vocab_path, profile_key) in expected_gens.items():
        gm = gens.get(method)
        if gm is None:
            errors.append(
                "%s does not construct IRI as VOCAB_IRI+local from a shape gem TTL"
                % method
            )
            continue
        gem_token, filename, declared_profile = gm.group(2), gm.group(3), gm.group(4)
        if declared_profile != profile_key:
            errors.append(
                "%s profile_key %s != %s" % (method, declared_profile, profile_key)
            )
        vp = root / vocab_path
        if not vp.is_file():
            errors.append("missing %s" % vocab_path.as_posix())
            continue
        vtext = vp.read_text(encoding="utf-8", errors="replace")
        vocab_iri, names = parse_vocab_iris(vtext)
        if not vocab_iri:
            errors.append("%s has no VOCAB_IRI" % vocab_path.as_posix())
            continue
        if not names:
            errors.append("%s has no OPERATIONS request/response shapes" % vocab_path.as_posix())
            continue
        prefix = profile_key + "::"
        for name in names:
            local = name[len(prefix):] if name.startswith(prefix) else name.split("::", 1)[-1]
            add(name, gem_token, filename, vocab_iri + local, method)

    return entries


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
    entries = catalog_entries(root, errors)
    ttl_cache = {}
    nodeshape_count = 0
    files_examined = set()

    for rec in entries:
        rel = rec["file"]
        if rel not in ttl_cache:
            p = root / rel
            files_examined.add(rel)
            if not p.is_file():
                ttl_cache[rel] = None
                errors.append("catalog %s resolves missing TTL %s" % (rec["shape"], rel))
                continue
            shapes = parse_nodeshapes(p.read_text(encoding="utf-8", errors="replace"))
            ttl_cache[rel] = shapes
            nodeshape_count += len(shapes)
            print("  ttl %s (%d NodeShapes)" % (rel, len(shapes)))
        shapes = ttl_cache[rel]
        if shapes is None:
            continue
        by_iri = {s["iri"]: s for s in shapes}
        by_local = {}
        for s in shapes:
            by_local.setdefault(s["local"], []).append(s)
        iri = rec["iri"]
        local = local_of(iri)
        if iri in by_iri:
            print("  ok %s -> %s" % (rec["shape"], iri))
            continue
        alts = by_local.get(local) or []
        if alts:
            ttl_iris = sorted({s["iri"] for s in alts})
            errors.append(
                "IRI DIVERGENCE shape=%s catalog=%s ttl=%s file=%s (local name %s unchanged)"
                % (rec["shape"], iri, ttl_iris, rel, local)
            )
        else:
            errors.append(
                "CATALOG IRI ABSENT FROM TTL shape=%s iri=%s file=%s"
                % (rec["shape"], iri, rel)
            )

    n_entries = len(entries)
    print("  catalog entries examined: %d" % n_entries)
    print("  TTL NodeShapes examined: %d" % nodeshape_count)
    print("  TTL files examined: %d" % len(files_examined))
    ok_pop, _ = emit_population(
        n_entries + nodeshape_count,
        skipped=0,
        skipped_reason="catalog entries with no TTL NodeShape in the resolved file",
    )
    if not ok_pop:
        return 1
    if errors:
        print("CATALOG TTL IRI FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:40]:
            print("  " + e, file=sys.stderr)
        return 1
    print("catalog-ttl-iri: OK (%d entries, %d NodeShapes)" % (n_entries, nodeshape_count))
    return 0


if __name__ == "__main__":
    sys.exit(main())
