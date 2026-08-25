# Two-pod CPCP deployment (Kamal)

`rails-cpcp` makes the two-pod CPCP shape **mandatory**: the Rails app is the
**BACK** pod, and a **distinct** FRONT pod (built from [`../front/Dockerfile`](../front/Dockerfile))
talks to it only over JSON-RPC-LD. Co-locating them in one container is not a
conformant CPCP deployment.

## Kamal mapping

- **BACK** = the primary Kamal `service` (your Rails image) with the engine mounted at `/_cpcp`.
- **FRONT** = a Kamal `accessory` with its OWN `image` (the rails-cpcp FRONT), its own
  container, proxied at a distinct host, pointed at the BACK via `BACK_URL`.

Copy [`deploy.cpcp.yml`](./deploy.cpcp.yml) to `config/deploy.cpcp.yml`, fill in your
host/registry, build the FRONT image from `front/`, then:

```bash
kamal deploy -c config/deploy.cpcp.yml    # BACK service + FRONT accessory, one revision
```

On a shared VPS already running kamal-proxy (e.g. the magenticmarket.ai box at
31.97.8.47), the FRONT accessory lands beside the existing BACK service and is
proxied at a distinct FQDN. This is the low-friction two-pod path; GalaxyGate /
mmg-k3s remain the higher-order pod-provisioning route. Both build from one source
revision and bind to one CID digest (`GET /_cpcp/up` reports `cid_digest`).
