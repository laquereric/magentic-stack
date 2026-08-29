#!/usr/bin/env python3
"""Compiler interface for closed-shape artifacts.

Ruby is the FIRST BACKEND, not a special exception (Manus 2026-08-29b).
A second backend slots in by implementing Backend.shapes(); it must not
require changes to Source or Compare.

Layering:
  ClosedShapeIR   the intermediate representation
  Source          TTL NodeShapes -> IR  (no Ruby)
  Backend         protocol; RubyBackend is the only implementation today
  Compare         IR vs IR, keyed by live CpcpAdapter.wrap sites

Does not execute SHACL. Does not edit TTL or Ruby.
"""
from __future__ import annotations
import re
import sys
from dataclasses import dataclass
from pathlib import Path


def canon(name: str) -> str:
    name = name.split(":")[-1].split("#")[-1].split("/")[-1]
    name = re.sub(r"(?<!^)(?=[A-Z])", "_", name)
    return name.lower()


def local_of(iri: str) -> str:
    return iri.rstrip("/").split("#")[-1].split("/")[-1]


def ruby_candidates(name: str) -> set[str]:
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


@dataclass(frozen=True)
class ClosedShapeIR:
    """Language-neutral closed-shape artifact.

    properties: the granted/mentioned predicate set, already canon'd.
    closed: whether unknown properties are refused.
    ignored: sh:ignoredProperties (canon'd); empty on backends that have none.
    """
    shape: str
    closed: bool
    ignored: frozenset
    properties: frozenset
    origin: str
    file: str
    line: int | None = None


@dataclass
class WrapSite:
    operation: str
    file: str
    line: int
    request_shape: str
    response_shape: str


class Source:
    """TTL frontend. Reads both trees; runtime-pin wins on a local-name clash
    (that file is what config.shape_root pins). No Ruby knowledge."""

    RUNTIME_GLOB = "gems/rails-osi-level-8/data/osi-level-8/*.ttl"
    CANONICAL_GLOB = "gems/osi-level-8-profiles/profile-*/shapes/*.ttl"

    def __init__(self, root: Path):
        self.root = root

    def files(self):
        # Shadow: named by the binding manifest, not a directory glob.
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from shape_resolution import named_ttl_files, load_manifest
        files = named_ttl_files(self.root, load_manifest(self.root))
        runtime = [p for p in files if "/rails-osi-level-8/data/osi-level-8/" in p.as_posix()]
        canonical = [p for p in files if "/osi-level-8-profiles/" in p.as_posix()]
        return runtime, canonical

    def shapes(self) -> dict[str, ClosedShapeIR]:
        from rdflib import Graph, Namespace, RDF, URIRef
        SH = Namespace("http://www.w3.org/ns/shacl#")
        runtime, canonical = self.files()
        # runtime first so a clash keeps the pin
        ordered = list(runtime) + [p for p in canonical if p not in runtime]
        out: dict[str, ClosedShapeIR] = {}
        for path in ordered:
            g = Graph()
            g.parse(path.as_posix(), format="turtle")
            rel = path.relative_to(self.root).as_posix() if self.root in path.parents else path.as_posix()
            lines = _shape_lines(path)
            for shape in g.subjects(RDF.type, SH.NodeShape):
                if not isinstance(shape, URIRef):
                    continue
                local = local_of(str(shape))
                if local in out:
                    continue
                closed = any(str(v).lower() in ("true", "1") for v in g.objects(shape, SH.closed))
                ignored = frozenset(
                    canon(str(t))
                    for lst in g.objects(shape, SH.ignoredProperties)
                    for t in _rdf_list(g, lst)
                )
                props = set()
                for pshape in g.objects(shape, SH.property):
                    pth = g.value(pshape, SH.path)
                    if pth is not None:
                        props.add(canon(str(pth)))
                out[local] = ClosedShapeIR(
                    shape=local,
                    closed=bool(closed),
                    ignored=ignored,
                    properties=frozenset(props),
                    origin="ttl",
                    file=rel,
                    line=lines.get(local),
                )
        return out


class Backend:
    """Compiler backend protocol. A second language implements this class."""

    name = "abstract"

    def shapes(self) -> dict[str, ClosedShapeIR]:
        raise NotImplementedError


class RubyBackend(Backend):
    """Hand-written Grounding.closed_shape_violations is today's Ruby artifact.

    It is not generated yet. The backend still produces ClosedShapeIR so a
    later generated-Ruby backend can replace this parser without touching
    Source or Compare.
    """

    name = "ruby"
    GROUNDING = Path("gems/rails-osi-level-8/lib/rails_osi_level_8/grounding.rb")

    def __init__(self, root: Path):
        self.root = root

    def shapes(self) -> dict[str, ClosedShapeIR]:
        path = self.root / self.GROUNDING
        if not path.is_file():
            return {}
        src = path.read_text(encoding="utf-8", errors="replace")
        start = src.find("def closed_shape_violations")
        body = src[start:] if start >= 0 else src
        blocks = re.split(r"\n      when ", body)
        out: dict[str, ClosedShapeIR] = {}
        rel = self.GROUNDING.as_posix()
        for block in blocks[1:]:
            head, _, rest = block.partition("\n")
            rest = re.split(r"\n      else\b", rest)[0]
            names = re.findall(r'"([A-Za-z0-9]+::[A-Za-z0-9]+Shape)"', head)
            props = set()
            for m in re.finditer(r'violation\(\s*graph,\s*"([^"]+)"', rest):
                props.add(canon(m.group(1)))
            # Ruby does not refuse unknown keys; it checks named required/forbidden
            # fields. That is not sh:closed.
            closed = False
            line = src[: src.find(block) if block in src else 0].count("\n") + 1
            ir = ClosedShapeIR(
                shape=names[0] if names else "unknown",
                closed=closed,
                ignored=frozenset(),
                properties=frozenset(props),
                origin="ruby",
                file=rel,
                line=line,
            )
            for n in names:
                out[n] = ir
                out[n.split("::")[-1]] = ir
        return out


WRAP_FILES = [
    Path("runtimes/mind-pod/app/config/initializers/rails_cpcp.rb"),
    Path("runtimes/mind-pod/app/config/initializers/rails_cpcp_session.rb"),
]


def parse_wraps(root: Path) -> list[WrapSite]:
    wraps = []
    rx_one = re.compile(
        r'request_shape:\s*"([^"]+)"\s*,\s*response_shape:\s*"([^"]+)"'
    )
    op_rx = re.compile(r'operation\s+"([^"]+)"')
    for relf in WRAP_FILES:
        p = root / relf
        if not p.is_file():
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        for m in rx_one.finditer(text):
            req, res = m.group(1), m.group(2)
            line = text[: m.start()].count("\n") + 1
            prefix = text[: m.start()]
            ops = op_rx.findall(prefix)
            operation = ops[-1] if ops else "unknown"
            wraps.append(WrapSite(
                operation=operation,
                file=relf.as_posix(),
                line=line,
                request_shape=req,
                response_shape=res,
            ))
    return wraps


def _lookup(index: dict[str, ClosedShapeIR], raw: str) -> ClosedShapeIR | None:
    for cand in ruby_candidates(raw):
        if cand in index:
            return index[cand]
    local = raw.split("::")[-1]
    for key, ir in index.items():
        if local_of(key) == local or local_of(ir.shape) == local:
            return ir
        if ruby_candidates(key) & ruby_candidates(raw):
            return ir
    return None


def compare(wraps: list[WrapSite], source: dict, backend: dict) -> list[dict]:
    """Compare source IR to backend IR at each wrap site. Do not reconcile."""
    divergences = []
    for w in wraps:
        for role, raw in (("request", w.request_shape), ("response", w.response_shape)):
            ttl = _lookup(source, raw)
            ruby = _lookup(backend, raw)
            site = "%s:%d" % (w.file, w.line)
            base = {
                "operation": w.operation,
                "role": role,
                "shape": raw,
                "wrap_site": site,
            }
            if ttl is None:
                divergences.append({**base, "kind": "missing_ttl", "property": None,
                                    "because": "wrap names %s but no TTL NodeShape matches" % raw})
                continue
            if ruby is None:
                divergences.append({**base, "kind": "missing_ruby", "property": None,
                                    "because": "wrap names %s but Grounding has no branch" % raw})
                continue
            if ttl.closed != ruby.closed:
                divergences.append({
                    **base, "kind": "closed_mismatch", "property": None,
                    "ttl_closed": ttl.closed, "ruby_closed": ruby.closed,
                    "because": "%s TTL closed=%s Ruby closed=%s at %s"
                               % (raw, ttl.closed, ruby.closed, site),
                })
            if ttl.ignored != ruby.ignored:
                only_ttl = sorted(ttl.ignored - ruby.ignored)
                only_ruby = sorted(ruby.ignored - ttl.ignored)
                for prop in only_ttl:
                    divergences.append({
                        **base, "kind": "ignored_only_in_ttl", "property": prop,
                        "because": "%s ignoredProperties %s is in TTL not Ruby at %s"
                                   % (raw, prop, site),
                    })
                for prop in only_ruby:
                    divergences.append({
                        **base, "kind": "ignored_only_in_ruby", "property": prop,
                        "because": "%s ignoredProperties %s is in Ruby not TTL at %s"
                                   % (raw, prop, site),
                    })
            only_ttl_p = sorted(ttl.properties - ruby.properties)
            only_ruby_p = sorted(ruby.properties - ttl.properties)
            for prop in only_ttl_p:
                divergences.append({
                    **base, "kind": "property_only_in_ttl", "property": prop,
                    "because": "%s property %s is in TTL not Ruby at %s" % (raw, prop, site),
                })
            for prop in only_ruby_p:
                divergences.append({
                    **base, "kind": "property_only_in_ruby", "property": prop,
                    "because": "%s property %s is in Ruby not TTL at %s" % (raw, prop, site),
                })
    divergences.sort(key=lambda d: (d["operation"], d["role"], d["kind"], d.get("property") or ""))
    return divergences


def divergence_key(d: dict) -> str:
    return "%s|%s|%s|%s" % (d["operation"], d["role"], d["kind"], d.get("property") or "")


def _rdf_list(g, head):
    from rdflib import RDF
    out = []
    seen = set()
    while head is not None and head != RDF.nil and head not in seen:
        seen.add(head)
        first = g.value(head, RDF.first)
        if first is not None:
            out.append(first)
        head = g.value(head, RDF.rest)
    return out


def _shape_lines(path: Path) -> dict:
    found = {}
    if not path.is_file():
        return found
    for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        m = re.search(r"(?:[A-Za-z0-9_]+:)?([A-Za-z0-9_]+)\s+a\s+sh:NodeShape", line)
        if m:
            found[m.group(1)] = i
    return found
