# runtimes/mind-pod/  🟢 OWN IT — MIND

The MIND container: runs the upstream agent (e.g. NVIDIA NOOA) in **OS-level
isolation**. Required because agents that can execute code must be isolated.

- **Reference POC:** `app-osi-8-nooa-poc`.
- Cannot bypass evidence paths: every Effect flows through BACK's `/_cpcp` seam.
- The upstream agent is pinned via [`../../upstreams/nooa/`](../../upstreams/nooa/).
