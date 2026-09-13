# gems/adapters/monty/  🟢 OWN IT

Boundary adapter for the pydantic/monty pin (ADR 0070).

Monty is a Rust Python-subset VM. MIND will wrap NOOA's CodeAct strategy
so model-written cells run in monty, not in CPython. The functions and
mounts passed into the VM *are* the Effect surface.

**This directory is the door. It does not yet wrap anything.** The pin is
`kind: declared` in `upstreams/manifests/monty.pin.json` until a gitlink
exists. Do not import monty from `runtimes/`.
