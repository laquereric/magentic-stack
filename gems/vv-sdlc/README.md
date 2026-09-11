# vv-sdlc

Private gem. **AI-in-SDLC as a BPMN process** on `vv-bpmn-bbo`.

Not on rubygems.org. No XML importer. **No CPCP in this gem** — `bpmn.*`
registers on magentic-stack BACK (`BpmnSeam`), which is the sole writer
(ADR 0056). This gem is the seed + token engine that seam calls.

Source: `magentic-market-ai/docs/research/AiSDLC.md` (Andrus, May 2026).
The unit of assistance is the **task**. Agent output is a confident junior
who has read every textbook and worked at none of our companies.

## The process (`definition_key=sdlc`)

```
Start → AgentDraft → AgentTests → RealityTest → HumanReview → GwReview
                                                              ├ reject → End_reject
                                                              └ accept → ObsCheck → End_ok
```

| Step | Kind | Why |
|---|---|---|
| AgentDraft | service | the easy 70% |
| AgentTests | service | internally coherent, **not evidence** |
| RealityTest | service | independent oracle (integration / contract) |
| HumanReview | **user** | review is the bottleneck; claimed by `Vv::Base::Actor` |
| ObsCheck | service | observability is the safety net |

You cannot skip HumanReview: only the current job completes.

## Specs

```
bundle exec rspec
```
