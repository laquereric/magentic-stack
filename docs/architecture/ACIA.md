# ACIA — presentation, not protocol

ACIA is four things, in this order. Each already has a home. Do not
rebuild what is named here.

rails-osi-level-8 currently **holds** ACIA (Profile 9) because that is
where the first renderer landed. That is why ACIA has no name of its
own. The move out is ADR 0003; this document is the contract the
move has to keep.

## a) Presentation

ACIA is the presentation layer and nothing else. HTML is never a
source. Props are closed. The SLT tuple is mandatory.

See `interfaces/rails-osi-level-8/lib/rails_osi_level_8/profile9/acia.rb`
and `profile9/renderer.rb`. Forbidden prop keys include `html`,
`style`, `dangerouslySetInnerHTML`, `onClick`, `href`. Unresolved
tokens yield a RefusalNotice, never an HTML fallback. A page that
can be written as markup in a prop is a page that skipped the
contract.

What was wrong: treating the renderer as "whatever HTML we emit."
The document is the source; HTML is a projection of it.

## b) A tree of components, each with a prop table

Closed component-kind vocabulary (19 kinds, ghis-19@1). Each node
carries `props.valueJson`, `propsSchemaCid`, and

```
slt(semanticRole, contentRole, layoutKind, layoutArity, behaviorKind)
```

plus optional `responsiveSignature` / `tokenSignature`. The prop
table is first-class: it is what makes a node **inspectable**
rather than rendered-and-gone. Inspect replaces the document (new
digest, new correlation); it does not annotate the old HTML.

What was wrong: props as incidental renderer hints. Without a
table, `ux.inspect` has nothing to return that is not pixels.

## c) The top of the ACIA tree is the Rails page layout

This is already built and under-stated.

`app-oriented-translation` `AciaToHerb` materializes the **top** of
the tree as static HERB and leaves everything below a cut as ACIA
render **references**. The implementation uses `DEFAULT_CUT = 2`.
That number is how today's board happens to be walked, not the
contract.

**The contract:** the ACIA `PageShell` (semanticRole `landmark`)
**is** the Rails layout. What a designer opens as a layout file is
the top of the same tree BACK already admitted. Everything that
still churns stays a typed slot (`<%= acia.brd_col_inputs %>`),
filled with the Profile 9 renderer's own output for that node —
re-rendering a subtree in isolation would mint different cids and
break provenance.

What was wrong: "cut depth 2" as if the page were a magic number.
Change the board, the depth moves; the PageShell/layout identity
does not.

## d) SPARQL read/write (surface only)

Two gems that **do not exist yet**:

| gem | face |
|---|---|
| `mmg-acia` | read — SPARQL over admitted ACIA / presentation graphs |
| `mmg-acia-crud` | write — the same graphs, with CPCP write-access obligations (`operationId`, sole writer) |

Describe only. Do not implement here.

**Store:** native oxigraph backs this surface. That prerequisite is
**satisfied** (ADR 0003 decision 2). The live variable is
`MM_OXIGRAPH_URL` (container `mm-graph` on the `mm-pod` network,
volume `mm_graph_data`). `MMG_GRAPH_URL` was a dead name: nothing
read it, so "set MMG_GRAPH_URL" would have configured silence.
`graph.publish` / `graph.query` / `graph.count` round-trip and
survive a rebuild.

The missing piece is no longer the store. It is the two gems and
the ACIA-shaped named graphs they would query. Until those exist,
oxigraph holds whatever `mmg-graph` already publishes — not ACIA
trees.
