# gems/adapters/monty/  🟢 OWN IT

Boundary adapter for the pydantic/monty pin (ADR 0070).

This directory is the only place that may reach `upstreams/monty`
(ADR 0030). The gitlink path is `submodule_path` in
`upstreams/manifests/monty.pin.json`.

`run(code)` returns a never-raise envelope. It does not `exec` in
CPython. Missing `pydantic_monty` is `reason: monty_absent`.

MIND wraps NOOA CodeAct by intercepting `execute_python` and **not**
calling `nxt` (`runtimes/mind-pod/mind/mind_codeact.py`). Cells in
`mind_cells.py` stay DATA.

The MIND image installs `pydantic-monty==0.0.23` and copies this
directory onto `PYTHONPATH` (`/opt/magentic/adapters`) via
`mind/bin/prepare`. Distroless PATH omits `/deps/bin`, so the image
sets `MONTY_BIN=/deps/bin/monty`. The intercept is live.
