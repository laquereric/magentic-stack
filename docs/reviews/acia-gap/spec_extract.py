import sys
from rdflib import Graph, Namespace, RDF
from rdflib.namespace import SH

UX = Namespace("https://w3id.org/cpcp/osi8/ux#")
TTL = "/Users/ericlaquer/NoIcloud/magentic-stack/gems/osi-level-8-profiles/profile-9-governed-human-interaction-surface/shapes/osi-level-8-profile-9-ghis.shacl.ttl"

g = Graph(); g.parse(TTL, format="turtle")

def local(t): return str(t).rsplit("#", 1)[-1] if "#" in str(t) else str(t).rsplit("/", 1)[-1]
def rdf_list(node):
    out = []
    while node and node != RDF.nil:
        f = g.value(node, RDF.first)
        if f is not None: out.append(f)
        node = g.value(node, RDF.rest)
    return out

print("=" * 74)
print("THE SPECIFICATION  (Profile 9 GHIS normative SHACL)")
print("=" * 74)
shapes = sorted(set(g.subjects(RDF.type, SH.NodeShape)), key=lambda s: local(s))
print("NodeShapes: %d   ux: terms: %d\n" % (
    len(shapes), len({t for t in set(g.subjects()) | set(g.objects()) if str(t).startswith(str(UX))})))

ENUMS = {}
for sh in shapes:
    tc = g.value(sh, SH.targetClass)
    closed = g.value(sh, SH.closed)
    props = []
    for p in g.objects(sh, SH.property):
        path = g.value(p, SH.path)
        if path is None: continue
        bits = []
        if g.value(p, SH.minCount) is not None: bits.append("min%s" % g.value(p, SH.minCount))
        if g.value(p, SH.maxCount) is not None: bits.append("max%s" % g.value(p, SH.maxCount))
        if g.value(p, SH.datatype) is not None: bits.append(local(g.value(p, SH.datatype)))
        if g.value(p, SH.nodeKind) is not None: bits.append(local(g.value(p, SH.nodeKind)))
        if g.value(p, SH["class"]) is not None: bits.append("class=%s" % local(g.value(p, SH["class"])))
        hv = g.value(p, SH.hasValue)
        if hv is not None: bits.append("=%s" % local(hv))
        inn = g.value(p, SH['in'])
        vals = [local(v) for v in rdf_list(inn)] if inn is not None else []
        if vals:
            ENUMS[local(path)] = vals
            bits.append("in[%d]" % len(vals))
        props.append((local(path), " ".join(bits)))
    print("%-26s target=%-16s closed=%s  props=%d" % (
        local(sh), local(tc) if tc else "-", "yes" if closed else "no", len(props)))
    for name, b in sorted(props):
        print("      %-24s %s" % (name, b))

print("\n" + "=" * 74)
print("CLOSED ENUMERATIONS THE SPEC DEFINES")
print("=" * 74)
for k in sorted(ENUMS):
    print("%-16s %2d  %s" % (k, len(ENUMS[k]), " ".join(ENUMS[k])))
