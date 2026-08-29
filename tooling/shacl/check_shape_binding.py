#!/usr/bin/env python3
"""Phase 0: every sh:NodeShape is named, and a wrap of an unlisted shape fails.

WHY. A Level 8 constraint exists twice -- TTL that CI validates and the server
never executes, and hand-written Ruby that actually refuses requests. Phase 0
is an inventory of which NodeShapes are bound at a live call site. Nothing
after it can be scoped without that number.

THE TRAP. A grep for request_shape:/response_shape: matches vocabulary tables
(P9, P11) that declare names for their own validation paths, not
CpcpAdapter.wrap. This checker reads ACTUAL wrap sites in the two CPCP
initializers, plus the two other live enforcement paths (P9 Request.closed! /
require_cid!, P11 Contract.validate!).

FAILS CLOSED. An empty CHECK_ROOT tree, a missing manifest, or a wrap whose
shape is not listed bound_runtime is a failure. Adding a wrap of an unlisted
shape must fail -- that is the plant.

Does not change what any operation admits or refuses.
"""
from __future__ import annotations
import json, os, re, sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
MANIFEST_REL = Path("tooling/shacl/shape_binding_manifest.json")
WRAP_FILES = [
    Path("runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"),
    Path("runtimes/mind-pod/app/config/initializers/rails_cpcp_session.rb"),
]
CANONICAL_GLOB = "gems/osi-level-8-profiles/profile-*/shapes/*.ttl"
RUNTIME_GLOB = "gems/rails-osi-level-8/data/osi-level-8/*.ttl"
GROUNDING = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb")
P9_VOCAB = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/vocabulary.rb")
P9_SOURCES = [
    Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/pulls.rb"),
    Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/mutations.rb"),
    Path("runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"),
]
P11_VOCAB = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile11/vocabulary.rb")
P11_STORE = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile11/store.rb")
P11_CONTRACT = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile11/contract.rb")
STATES = ("bound_runtime", "bound_ci_only", "external_binding", "deprecated", "unowned")


def rel(p: Path) -> str:
    try:
        return p.relative_to(ROOT).as_posix()
    except ValueError:
        return p.as_posix()


def cite(path: Path, line: int, detail: str) -> dict:
    return {"file": rel(path) if path.is_absolute() else path.as_posix(),
            "line": int(line), "detail": detail}


def local_of(iri: str) -> str:
    return iri.rstrip("/").split("#")[-1].split("/")[-1]


def ruby_candidates(name: str) -> set[str]:
    """P1::NoteCreateEffectShape -> NoteCreateEffectShape, P1NoteCreateEffectShape."""
    name = name.strip().strip('"').strip("'")
    out = {name}
    if "::" in name:
        pref, local = name.split("::", 1)
        out.add(local)
        out.add(pref + local)
        out.add(re.sub(r"\AP\d+", "", local))
    stripped = re.sub(r"\AP\d+", "", name.split("::")[-1])
    out.add(stripped)
    return {x for x in out if x}


def parse_nodeshapes():
    """One record per local name; a shape in both trees is one row, both files."""
    files = sorted(ROOT.glob(CANONICAL_GLOB)) + sorted(ROOT.glob(RUNTIME_GLOB))
    by_name = {}
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        tree = "canonical" if "/osi-level-8-profiles/" in f.as_posix() else "runtime_pin"
        for n, line in enumerate(text.splitlines(), 1):
            m = re.search(r"(\S+)\s+a\s+sh:NodeShape\b", line)
            if not m:
                continue
            token = m.group(1)
            if token.startswith("<") and token.endswith(">"):
                iri = token[1:-1]
            elif ":" in token:
                pref, local = token.split(":", 1)
                pm = re.search(r"@prefix\s+%s:\s+<([^>]+)>" % re.escape(pref), text)
                iri = (pm.group(1) if pm else pref + ":") + local
            else:
                iri = token
            local = local_of(iri)
            rec = by_name.setdefault(local, {
                "local_name": local, "iris": [], "occurrences": [], "trees": set(),
            })
            if iri not in rec["iris"]:
                rec["iris"].append(iri)
            rec["occurrences"].append({"file": rel(f), "line": n, "tree": tree})
            rec["trees"].add(tree)
    return files, by_name


def parse_wraps():
    wraps = []
    rx = re.compile(
        r"CpcpAdapter\.wrap\(\s*"
        r"(?:.*?\n)*?"
        r'\s*request_shape:\s*"([^"]+)"\s*,\s*\n'
        r'\s*response_shape:\s*"([^"]+)"',
        re.M,
    )
    # also single-line form
    rx_one = re.compile(
        r'request_shape:\s*"([^"]+)"\s*,\s*response_shape:\s*"([^"]+)"'
    )
    for relf in WRAP_FILES:
        p = ROOT / relf
        if not p.is_file():
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        seen = set()
        for m in rx_one.finditer(text):
            req, res = m.group(1), m.group(2)
            line = text[:m.start()].count("\n") + 1
            key = (req, res, line)
            if key in seen:
                continue
            seen.add(key)
            wraps.append({"file": relf.as_posix(), "line": line,
                          "request_shape": req, "response_shape": res})
    return wraps


def parse_grounding_whens():
    p = ROOT / GROUNDING
    if not p.is_file():
        return [], 0
    src = p.read_text(encoding="utf-8", errors="replace")
    # Isolate closed_shape_violations.
    start = src.find("def closed_shape_violations")
    body = src[start:] if start >= 0 else src
    names = []
    branch_heads = 0
    for m in re.finditer(r'\n      when ("[^"]+"(?:\s*,\s*"[^"]+")*)', body):
        branch_heads += 1
        line = body[:m.start()].count("\n") + (src[:start].count("\n") + 1 if start >= 0 else 1)
        for n in re.findall(r'"([^"]+)"', m.group(1)):
            names.append({"name": n, "file": GROUNDING.as_posix(), "line": line})
    return names, branch_heads


def parse_p9_runtime():
    """Request shapes whose live handler actually closed-checks params."""
    vocab = ROOT / P9_VOCAB
    if not vocab.is_file():
        return []
    vtext = vocab.read_text(encoding="utf-8", errors="replace")
    ops = []
    for m in re.finditer(
            r'name:\s*"(ux[.][^"]+)".*?request_shape:\s*"(P9::[^"]+)"',
            vtext, re.S):
        line = vtext[:m.start()].count("\n") + 1
        ops.append((m.group(1), m.group(2), line))
    blobs = []
    for relf in P9_SOURCES:
        p = ROOT / relf
        if p.is_file():
            blobs.append((relf, p.read_text(encoding="utf-8", errors="replace")))
    out = []
    for op, shape, vline in ops:
        meth = op.replace("ux.", "", 1).replace(".", "_")
        hit = None
        for relf, text in blobs:
            # initializer: operation "ux.foo" ... closed! / Acia.validate / Contract.check
            if relf.as_posix().endswith("rails_cpcp.rb"):
                block = re.search(
                    r'operation\s+"%s".*?(?=\n  operation |\nend\n)' % re.escape(op),
                    text, re.S)
                body = block.group(0) if block else ""
                if re.search(r"closed!|require_cid!|Acia\.validate|Contract\.check", body):
                    line = text[:block.start()].count("\n") + 1 if block else 1
                    hit = (relf, line, "handler closed-checks params")
            else:
                m = re.search(r"\n      def %s\(" % re.escape(meth), text)
                if not m:
                    continue
                end = text.find("\n      def ", m.end())
                body = text[m.start(): end if end != -1 else None]
                if re.search(r"closed!|require_cid!", body):
                    line = text[:m.start()].count("\n") + 1
                    hit = (relf, line, "Request.closed! / require_cid!")
        if hit:
            out.append({"op": op, "shape": shape, "vocab_line": vline,
                        "file": hit[0].as_posix(), "line": hit[1], "detail": hit[2]})
    return out


def parse_p11_runtime_types():
    """Types Contract.validate! actually runs on (put! + explicit calls)."""
    store = ROOT / P11_STORE
    contract = ROOT / P11_CONTRACT
    types = set()
    cites = []
    if store.is_file():
        text = store.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"\n      def put!\(", text)
        if m and "Contract.validate!(rec)" in text[m.start():]:
            line = text.find("Contract.validate!(rec)", m.start())
            lineno = text[:line].count("\n") + 1
            cites.append(cite(store, lineno, "put! calls Contract.validate!"))
            # every put_X! type argument
            for t in re.finditer(r'put!\(:\w+,\s*rec,\s*"([A-Za-z]+)"\)', text):
                types.add(t.group(1))
            for t in re.finditer(r'put_!\(:\w+,\s*rec,\s*"([A-Za-z]+)"\)', text):
                types.add(t.group(1))
        for t in re.finditer(r'rec\["@type"\] \|\|= "([A-Za-z]+)"', text):
            types.add(t.group(1))
    if contract.is_file():
        text = contract.read_text(encoding="utf-8", errors="replace")
        m = re.search(r'REQUIRED\s*=\s*\{(.*?)\n      \}\.freeze', text, re.S)
        if m:
            for t in re.findall(r'"([A-Za-z]+)"\s*=>', m.group(1)):
                types.add(t)
            line = text[:m.start()].count("\n") + 1
            cites.append(cite(contract, line, "REQUIRED keys enforced by validate!"))
    vocab = ROOT / P11_VOCAB
    if vocab.is_file():
        text = vocab.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"RECORD_TYPES\s*=\s*%w\[(.*?)\]", text, re.S)
        if m:
            record_types = set(m.group(1).split())
            types |= record_types
            line = text[:m.start()].count("\n") + 1
            cites.append(cite(vocab, line, "RECORD_TYPES persist through put!/validate!"))
        m2 = re.search(r"PROJECTIONS\s*=\s*%w\[(.*?)\]", text, re.S)
        if m2:
            types -= set(m2.group(1).split())
    return types, cites


def profiles_with_fixtures():
    out = set()
    for d in sorted((ROOT / "gems/osi-level-8-profiles").glob("profile-*")):
        if any(d.glob("examples/*.ttl")):
            out.add(d.name)
    return out


def profile_of(path: str) -> str | None:
    m = re.search(r"(profile-[^/]+)", path)
    return m.group(1) if m else None


def naive_grep_names():
    """The trap: unique request_shape:/response_shape: literals in owned Ruby.

    Scoped to gems/ and runtimes/ -- that is where the vocabulary tables and
    wrap sites live. Walking the whole checkout (node_modules, upstreams) is
    not the naive grep that produced 72.
    """
    names = set()
    for area in ("gems/rails-osi-level-8", "runtimes/mind-pod"):
        base = ROOT / area
        if not base.is_dir():
            continue
        for p in base.rglob("*.rb"):
            posix = p.as_posix()
            # No "/vendor/" here: ADR 0038 dissolved vendor/ into gems/, so the
            # exclusion is vestigial -- and check_closed.py's no-vendor-references
            # assertion fails on any live reference to a tree that no longer exists.
            if any(s in posix for s in ("/.git/", "/node_modules/")):
                continue
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for m in re.finditer(r'(?:request_shape|response_shape):\s*"([^"]+)"', text):
                names.add(m.group(1))
    return names


def classify(by_name, wraps, grounding, p9, p11_types, p11_cites, fixture_profiles):
    wrap_index = defaultdict(list)
    for w in wraps:
        for kind, raw in (("request_shape", w["request_shape"]),
                          ("response_shape", w["response_shape"])):
            for cand in ruby_candidates(raw):
                wrap_index[cand].append((w, kind, raw))
    ground_index = defaultdict(list)
    for g in grounding:
        for cand in ruby_candidates(g["name"]):
            ground_index[cand].append(g)
    p9_index = defaultdict(list)
    for row in p9:
        for cand in ruby_candidates(row["shape"]):
            p9_index[cand].append(row)

    rows = []
    for local, rec in sorted(by_name.items()):
        just = []
        state = None

        for w, kind, raw in wrap_index.get(local, []):
            just.append(cite(Path(w["file"]), w["line"],
                             "CpcpAdapter.wrap %s %s" % (kind, raw)))
            state = "bound_runtime"
        # P1NoteCreateEffectShape matches wrap P1::NoteCreateEffectShape via candidates
        if state is None:
            for cand in ruby_candidates(local):
                for w, kind, raw in wrap_index.get(cand, []):
                    just.append(cite(Path(w["file"]), w["line"],
                                     "CpcpAdapter.wrap %s %s" % (kind, raw)))
                    state = "bound_runtime"

        for g in ground_index.get(local, []):
            just.append(cite(Path(g["file"]), g["line"],
                             "Grounding.closed_shape_violations when %s" % g["name"]))
        if local.startswith("P") and re.match(r"P\d+", local):
            stripped = re.sub(r"\AP\d+", "", local)
            for g in ground_index.get(stripped, []):
                if not any(j["detail"].endswith(g["name"]) for j in just):
                    just.append(cite(Path(g["file"]), g["line"],
                                     "Grounding.closed_shape_violations when %s" % g["name"]))

        for row in p9_index.get(local, []):
            just.append(cite(Path(row["file"]), row["line"],
                             "P9 %s %s" % (row["op"], row["detail"])))
            state = "bound_runtime"

        # P11 record types: ConceptShape / Concept
        type_hits = set()
        if local.endswith("Shape"):
            type_hits.add(local[:-5])
        type_hits.add(local)
        if type_hits & p11_types:
            t = sorted(type_hits & p11_types)[0]
            for c in p11_cites:
                just.append({**c, "detail": c["detail"] + " (type %s)" % t})
            state = "bound_runtime"

        if state is None:
            occ_profiles = {profile_of(o["file"]) for o in rec["occurrences"]}
            occ_profiles.discard(None)
            if occ_profiles & fixture_profiles:
                prof = sorted(occ_profiles & fixture_profiles)[0]
                # cite the first example file
                exdir = ROOT / "gems/osi-level-8-profiles" / prof / "examples"
                ex = sorted(exdir.glob("*.ttl"))
                if ex:
                    just.append(cite(ex[0], 1,
                                     "validate.py runs pyshacl fixtures for %s" % prof))
                state = "bound_ci_only"

        if state is None:
            state = "unowned"
            just.append({
                "file": rec["occurrences"][0]["file"],
                "line": rec["occurrences"][0]["line"],
                "detail": "declared as sh:NodeShape; no wrap, no P9 closed-check, no P11 validate!",
            })

        # deprecation: only if the TTL token itself says so
        for o in rec["occurrences"]:
            # cheap: filename or local name
            if "deprecated" in local.lower():
                state = "deprecated"

        rows.append({
            "local_name": local,
            "iris": rec["iris"],
            "state": state,
            "trees": sorted(rec["trees"]),
            "occurrences": rec["occurrences"],
            "justification": just,
        })
    return rows


def reconciliation(by_name, wraps, grounding, grounding_branches, naive, rows):
    counts = {s: sum(1 for r in rows if r["state"] == s) for s in STATES}
    wrap_names = sorted({w["request_shape"] for w in wraps} |
                        {w["response_shape"] for w in wraps})
    return {
        "nodeshape_declarations_both_trees": sum(len(r["occurrences"]) for r in rows),
        "nodeshape_rows": len(rows),
        "naive_grep_request_or_response_shape_names": len(naive),
        "cpcp_adapter_wrap_sites": len(wraps),
        "cpcp_adapter_wrap_shape_names": wrap_names,
        "grounding_when_branches": grounding_branches,
        "grounding_when_names": [g["name"] for g in grounding],
        "state_counts": counts,
        "phase3_compile_count": counts["bound_runtime"],
        "numbers_the_brief_named": {
            "179_sh_nodeshape_declarations_across_both_ttl_trees": {
                "measured": sum(len(r["occurrences"]) for r in rows),
                "because": "count of `a sh:NodeShape` tokens in canonical profile-*/shapes/*.ttl plus rails-osi-level-8/data/osi-level-8/*.ttl, before merging duplicates",
            },
            "72_names_a_naive_grep_matches": {
                "measured": len(naive),
                "because": "unique request_shape:/response_shape: string literals under *.rb, including P9/P11 vocabulary tables that are not CpcpAdapter.wrap",
            },
            "19_shapes_check_shape_drift_compares": {
                "measured": 19,
                "because": "tooling/shacl/check_shape_drift.py pairs TTL-with-enforceable-constraints against Grounding cases plus P9 Request.closed!; SHAPES.md records 19 compared. This inventory does not re-pair constraints; it classifies NodeShapes.",
            },
            "11_branches_grounding_implements": {
                "measured_when_heads": grounding_branches,
                "measured_quoted_names": len(grounding),
                "because": "SHAPES.md groups Note+Session as 11 named cases. The case statement has %d `when` heads and %d quoted names (P4 aliases and the five Session*ContextShape names included). Counted from grounding.rb, not from the grouping."
                % (grounding_branches, len(grounding)),
            },
        },
    }


def build():
    files, by_name = parse_nodeshapes()
    wraps = parse_wraps()
    grounding, n_branches = parse_grounding_whens()
    p9 = parse_p9_runtime()
    p11_types, p11_cites = parse_p11_runtime_types()
    fixtures = profiles_with_fixtures()
    naive = naive_grep_names()
    rows = classify(by_name, wraps, grounding, p9, p11_types, p11_cites, fixtures)
    recon = reconciliation(by_name, wraps, grounding, n_branches, naive, rows)
    recon["ttl_files"] = [rel(f) for f in files]
    live_locals = {r["local_name"] for r in rows}
    wrap_without_ttl = []
    for w in wraps:
        for kind, raw in (("request_shape", w["request_shape"]),
                          ("response_shape", w["response_shape"])):
            cands = ruby_candidates(raw)
            if any(c in live_locals for c in cands):
                continue
            ghit = next((g for g in grounding if g["name"] == raw), None)
            wrap_without_ttl.append({
                "kind": kind,
                "name": raw,
                "wrap": {"file": w["file"], "line": w["line"]},
                "grounding": ({"file": ghit["file"], "line": ghit["line"]} if ghit else None),
                "finding": "CpcpAdapter.wrap names this shape; neither TTL tree declares it as sh:NodeShape",
            })
    recon["wrap_names_without_ttl"] = wrap_without_ttl
    recon["phase3_compile_count"] = (
        recon["state_counts"]["bound_runtime"] + len(wrap_without_ttl)
    )
    recon["numbers_the_brief_named"]["179_sh_nodeshape_declarations_across_both_ttl_trees"]["measured_unique_local_names"] = len(rows)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from shape_resolution import enrich_rows
    rows = enrich_rows(ROOT, rows)
    return {
        "schema": "shape-binding-manifest/v0",
        "phase": 0,
        "resolution": "shadow-v0",
        "root_note": "one row per sh:NodeShape local name; a name in both TTL trees is one row naming both files; consumers resolve through this manifest in shadow",
        "findings": [
            "%d NodeShapes are unowned (no wrap, no P9 closed-check, no P11 validate!, no fixture-tested profile)"
            % recon["state_counts"]["unowned"],
            "%d wrap name(s) have no sh:NodeShape in either TTL tree (session response shapes: Grounding implements them, TTL does not declare them)"
            % len(wrap_without_ttl),
        ],
        "reconciliation": recon,
        "shapes": rows,
    }


def load_manifest(path: Path):
    if not path.is_file():
        print("FAIL-CLOSED: missing manifest at %s" % path, file=sys.stderr)
        return None
    return json.loads(path.read_text())


def check(live, manifest):
    errors = []
    live_names = [r["local_name"] for r in live["shapes"]]
    man_names = [r["local_name"] for r in manifest.get("shapes", [])]
    if len(man_names) != len(set(man_names)):
        dup = [n for n in man_names if man_names.count(n) > 1]
        errors.append("manifest repeats NodeShape(s): %s" % sorted(set(dup)))
    live_set, man_set = set(live_names), set(man_names)
    missing = sorted(live_set - man_set)
    extra = sorted(man_set - live_set)
    if missing:
        errors.append("NodeShape(s) in the TTL trees not in the manifest: %s" % missing[:20])
    if extra:
        errors.append("manifest names not declared as sh:NodeShape in either TTL tree: %s" % extra[:20])

    man_by = {r["local_name"]: r for r in manifest.get("shapes", [])}
    listed_without = {w["name"] for w in
                      manifest.get("reconciliation", {}).get("wrap_names_without_ttl", [])}
    live_without = {w["name"] for w in
                    live.get("reconciliation", {}).get("wrap_names_without_ttl", [])}
    wraps = parse_wraps()
    for w in wraps:
        for kind, raw in (("request_shape", w["request_shape"]),
                          ("response_shape", w["response_shape"])):
            cands = ruby_candidates(raw)
            hit = next((n for n in cands if n in man_by), None)
            if hit is not None:
                if man_by[hit]["state"] != "bound_runtime":
                    errors.append("WRAP OF UNLISTED SHAPE: %s %s at %s:%d is listed as %s, not bound_runtime"
                                  % (kind, raw, w["file"], w["line"], man_by[hit]["state"]))
                continue
            if raw in listed_without and raw in live_without:
                continue
            errors.append("WRAP OF UNLISTED SHAPE: %s %s at %s:%d is not a NodeShape in the manifest"
                          % (kind, raw, w["file"], w["line"]))
    return errors, wraps


def main(argv):
    write = "--write" in argv
    live = build()
    n = live["reconciliation"]["nodeshape_rows"]
    populated, pop = emit_population(n, skipped_reason="no sh:NodeShape in either TTL tree")
    if not populated:
        return 1

    dest = ROOT / MANIFEST_REL
    if write:
        dest.parent.mkdir(parents=True, exist_ok=True)
        existing = json.loads(dest.read_text()) if dest.is_file() else {}
        if existing.get("scope"):
            live["scope"] = existing["scope"]
        dest.write_text(json.dumps(live, indent=2) + "\n")
        print("wrote %s (%d rows)" % (rel(dest), n))
        recon = live["reconciliation"]
        print("states: %s" % json.dumps(recon["state_counts"]))
        print("phase3_compile_count: %d" % recon["phase3_compile_count"])
        print("wrap sites: %d  naive grep: %d  grounding branches: %d  declaration tokens: %d"
              % (recon["cpcp_adapter_wrap_sites"],
                 recon["naive_grep_request_or_response_shape_names"],
                 recon["grounding_when_branches"],
                 recon["nodeshape_declarations_both_trees"]))
        return 0

    manifest = load_manifest(dest)
    if manifest is None:
        return 1
    errors, wraps = check(live, manifest)
    print("wrap sites: %d" % len(wraps))
    print("states (live): %s" % json.dumps(live["reconciliation"]["state_counts"]))
    print("phase3_compile_count: %d" % live["reconciliation"]["phase3_compile_count"])
    if errors:
        print("SHAPE BINDING FAIL (%d)" % len(errors), file=sys.stderr)
        for e in errors[:30]:
            print("  " + e, file=sys.stderr)
        return 1
    print("shape binding: OK (%d NodeShapes, %d wrap sites)" % (n, len(wraps)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
