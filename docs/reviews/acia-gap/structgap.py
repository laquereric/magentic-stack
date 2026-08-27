from rdflib import Graph, Namespace, RDF
from rdflib.namespace import SH
STACK="/Users/ericlaquer/NoIcloud/magentic-stack"
TTL=STACK+"/gems/osi-level-8-profiles/profile-9-governed-human-interaction-surface/shapes/osi-level-8-profile-9-ghis.shacl.ttl"
def local(t): return str(t).rsplit("#",1)[-1] if "#" in str(t) else str(t).rsplit("/",1)[-1]
g=Graph(); g.parse(TTL, format="turtle")
UX=Namespace("https://w3id.org/cpcp/osi8/ux#")

def props_of(shape_local):
    for sh in g.subjects(RDF.type, SH.NodeShape):
        if local(sh)!=shape_local: continue
        out={}
        for p in g.objects(sh, SH.property):
            path=g.value(p, SH.path)
            if path is None: continue
            req = g.value(p, SH.minCount)
            out[local(path)] = int(req) if req is not None else 0
        return out
    return {}

comp=props_of("ComponentShape"); gov=props_of("GovernedFieldsShape")
req = {k:v for k,v in {**gov, **comp}.items()}

# what each implementation actually emits on a node
P9_EMITS = {"nodeId","componentKind","position","parent","inDocument",
            "semanticRole","contentRole","layoutKind","layoutArity","behaviorKind",
            "aciaDigest","schemaVersion","componentRegistryVersion","slug"}
ACIA_EMITS = {"semanticRole","contentRole","layoutKind","layoutArity","behaviorKind",
              "parent","position","stateProfileVersion"}

print("="*78)
print("STRUCTURAL GAP  -  ComponentShape + GovernedFields required of every node")
print("="*78)
print("%-26s %4s | %-18s | %-18s" % ("spec property","min","Profile 9 projection","mmg-acia node"))
print("-"*78)
for k in sorted(req):
    mark=lambda s: "emits" if k in s else ("-" )
    print("%-26s %4s | %-18s | %-18s" % (k, req[k] or "opt", mark(P9_EMITS), mark(ACIA_EMITS)))
print()
print("emitted but NOT in ComponentShape/GovernedFields:")
print("  Profile 9 :", " ".join(sorted(P9_EMITS - set(req))))
print("  mmg-acia  :", " ".join(sorted(ACIA_EMITS - set(req))))
