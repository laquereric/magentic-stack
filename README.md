# osi-level-8

**A Cybernetic Interface — Layer 8 of the reference model.**

The seven classical OSI layers carry bits between machines. **Level 8** is the
layer above Application (Layer 7): the *cybernetic interface* across which a
**Cyborg** — a responsible Human together with Compute Machinery (relational
databases, graph databases, LLMs) — perceives and acts on the world.

```
  Cyborg  <-reads-  Context      (perception)
  Cyborg  -has->     Effect       (action)
```

One side of the interface is the Cyborg. The other side is **Context** (what is
read) and **Effect** (what is done). The protocol that rides the interface is
**JSON-RPC-LD** (grounded, Linked-Data method calls), constrained by documented
**SHACL shapes**. **Profile 1** is the Cyborg Channel relational/graph model: every
triple is grounded on a class or an instance.

Level 7 transport is **HTTP** or, equivalently, **NATS**. Layers 1–6 are out of
scope here (cursory reference only).

## Layout (spec-first)

- `docs/`   — the normative specification document (OSI-like, ready for review).
- `shapes/` — the SHACL shapes that constrain the interface (the Cyborg Channel
  shapes are canonical in `json-rpc-ld`; this gem documents and references them).
- `lib/`    — a thin reference surface; the spec + shapes are the authority.

## Site

`osi-level-8.org` is served by the sibling gem `app-osi-level-8`.

## License

Apache-2.0 (open protocol specification). See `LICENSE`.
