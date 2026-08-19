# plugins/switchyard-routing/  [OFFICIAL]

**Switchyard LLM-assisted routing** (`mmg-switchyard`) - ThreeDot's LLM-assistance
plane over NVIDIA NeMo Switchyard. It gives ThreeDot LLM help for both **Develop**
(coding / syntax assist) and **RUN** (runtime assist), delivered via a ThreeDot CID.

**ThreeDot calls it in CPCP form** (over the `/_cpcp` seam). The MM-owned CID
contract + local policy boundary stay owned; Switchyard is the routing plane only.

- **Routing:** `:local` (MLX) | `:remote` (default local; private stays local);
  OpenAI<->Anthropic translation; observability spans; never-raise envelopes.
- **Canonical source:** `mmg-switchyard` - **PRIVATE**, `LicenseRef-DataYoursSoftwareMine-1.0`
  (restrictive). **Blocked for import** pending the same publish/relicense decision
  taken for [`../../apps/switchyard-offline/`](../../apps/switchyard-offline/).
- **Part of the ThreeDot plane** alongside [`../threedot-back`](../threedot-back/) and
  [`../threedot-vscode`](../threedot-vscode/); ThreeDot consumes it via CPCP.

> Corrected + relocated: was mis-scaffolded as `apps/switchyard-market-gateway`
> ("MagenticMarket integration"). It is ThreeDot's Switchyard LLM-assist routing,
> so it lives with the ThreeDot developer plane under `plugins/`, not `apps/`.
