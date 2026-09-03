# Gap 61: `make demo` could not run, and the docs taught a 404

`:13000` is the FRONT **web page**. FRONT is route-gated off `/_cpcp`
(gap 24). Teaching `curl localhost:13000/_cpcp` is a 404.

## What was broken

- `Makefile` `demo` invoked `test/docker-compose.demo.yml`, which does
  not exist. Canonical compose publishes SWITCH `:13001` only, so even
  with an overlay the wait on `:13000/up` would have been FRONT's port
  used as BACK.
- Historical overlay (`42a7aea`) published BACK on `:13000`. That file
  is gone. Recreating it would collide with extract FRONT.
- QUICKSTART, `.threedot/cid.json`, and troubleshooting curls pointed
  3dot and humans at FRONT `/_cpcp`.

## What it is now

- `make demo` uses the existing CI overlay
  (`test/docker-compose.ci.yml`) and talks to BACK on **`:3000`**, which
  is the Gate 1 Part C host path.
- Extract publishes BACK on **`:13002`** so the FRONT page stays
  `:13000`, SWITCH UI `:13001`, and host CPCP is a third port. In-pod
  MIND still uses `http://back:3000`.
- `.threedot/cid.json` `backUrl` is `http://localhost:13002`.
- Gate: `check_host_cpcp.py`. `localhost:13000/_cpcp` in host-facing
  files is a FAIL. Missing Makefile overlay is a FAIL.

Did not republish BACK on 13000. Did not mount `/_cpcp` on FRONT.
