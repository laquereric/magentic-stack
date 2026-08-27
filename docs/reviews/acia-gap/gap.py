import re, io, yaml
from rdflib import Graph, Namespace, RDF
from rdflib.namespace import SH

STACK = "/Users/ericlaquer/NoIcloud/magentic-stack"
TTL = STACK + "/gems/osi-level-8-profiles/profile-9-governed-human-interaction-surface/shapes/osi-level-8-profile-9-ghis.shacl.ttl"
RUBY = STACK + "/gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/acia.rb"
SEEDS = STACK + "/gems/mmg-acia/db/seeds/acia_dimensions.yml"

def local(t): return str(t).rsplit("#",1)[-1] if "#" in str(t) else str(t).rsplit("/",1)[-1]
def rdf_list(g, n):
    out=[]
    while n and n != RDF.nil:
        f=g.value(n, RDF.first)
        if f is not None: out.append(f)
        n=g.value(n, RDF.rest)
    return out

g=Graph(); g.parse(TTL, format="turtle")
spec={}
for sh in g.subjects(RDF.type, SH.NodeShape):
    for p in g.objects(sh, SH.property):
        path=g.value(p, SH.path); inn=g.value(p, SH['in'])
        if path is None or inn is None: continue
        spec[local(path)]=[local(v) for v in rdf_list(g, inn)]

src=io.open(RUBY,encoding="utf-8").read()
RUBY_MAP={"semanticRole":"SEMANTIC_ROLES","contentRole":"CONTENT_ROLES","layoutKind":"LAYOUT_KINDS",
          "layoutArity":"LAYOUT_ARITIES","behaviorKind":"BEHAVIOR_KINDS","variantName":"VARIANTS"}
ruby={}
for dim,const in RUBY_MAP.items():
    m=re.search(const+r"\s*=\s*%w\[(.*?)\]", src, re.S)
    if m: ruby[dim]=m.group(1).split()
m=re.search(r"COMPONENT_KINDS\s*=\s*%w\[(.*?)\]", io.open(STACK+"/gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/vocabulary.rb",encoding="utf-8").read(), re.S)
if m: ruby["componentKind"]=m.group(1).split()

seeds={k:[str(t) for t in v["tokens"]] for k,v in yaml.safe_load(io.open(SEEDS)).items() if k!="registry_version"}

print("="*78)
print("CONFORMANCE GAP  -  each implementation vs the normative Profile 9 shapes")
print("="*78)
print("%-16s %5s | %-22s | %-22s" % ("enumeration","spec","rails-osi-level-8 (Ruby)","mmg-acia (seed rows)"))
print("-"*78)
for dim in sorted(spec):
    s=spec[dim]
    def cmp(impl, name):
        if dim not in impl: return "MISSING"
        got=impl[dim]
        if got==s: return "match (%d)" % len(got)
        extra=[x for x in got if x not in s]; miss=[x for x in s if x not in got]
        if not extra and not miss: return "reordered (%d)" % len(got)
        bits=[]
        if miss: bits.append("-%d" % len(miss))
        if extra: bits.append("+%d" % len(extra))
        return "DIFFERS %s" % ",".join(bits)
    print("%-16s %5d | %-22s | %-22s" % (dim, len(s), cmp(ruby,"ruby"), cmp(seeds,"seeds")))
