# Deploy SHAs — local and remote, distinct from CPCP protocol

`.cpcp/package.json` already answers **compile** and **runtime protocol**
(layout, contract rev, CID, operations, wire format). Local deploy and
remote deploy are a different WHEN: the overlay runs because named
**image SHAs** and **blob SHAs** are at a placement.

That declaration lives at:

```
.cpcp/deploy.json
```

`kind` is `cpcp-deploy`. `vv-dependency-orch` reads it. It does **not**
re-parse Dockerfiles, `FLOOR.json`, or compose — those stay the pin
index (`vv-code-search`). This file is the line you change for deploy
identity; those files *reference* the same bytes.

## The four WHENS

| WHEN | Store | Identity |
|---|---|---|
| `compile` | `.cpcp/package.json` | contract rev, layout paths |
| `runtime_protocol` | `.cpcp/package.json` | CID, operations, scopes |
| `local_deploy` | `.cpcp/deploy.json` | image + blob SHA on this daemon / volume |
| `remote_deploy` | `.cpcp/deploy.json` | image + blob SHA on the registry / remote blob store |

A tag is never identity. `tag_for_humans` is a compose build-arg label
because `FROM name@sha256:…` without a registry prefix hits Docker Hub.

`index_digest: false` means unpublished — there is no registry digest.
That is a real state (the current rails-base and front-base floors).
`bin/docker-containers up` fails closed with `undeployable` if those
bytes are not on the daemon and cannot be pulled, unless a magentic-stack
checkout can build the floor.

Local FLOOR and last-public GHCR are **different identities** when the
floor has not been published. This file records both rather than
pretending they are one SHA.

## Clone → run

```
git clone <overlay>
cd <overlay>
bin/docker-containers up
```

The script walks to `.cpcp/deploy.json`, ensures `local_deploy` images
(pull if `index_digest` is a registry digest; build from
`MAGENTIC_STACK_ROOT` or `../magentic-stack` if unpublished), then
`docker compose up`. FRONT health is `health.url`.

```
bin/docker-containers down
bin/docker-containers status
```

Every magentic-stack overlay ships this file and this script. The
substrate demo (mind-pod) uses the same convention at
`magentic-stack/.cpcp/deploy.json`.
