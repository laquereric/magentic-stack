# The Decision Object: Where It Came From and Where It's Going

*Research summary, September 2026*

## Overview

"Decision Object" has no single coiner or canonical definition. Several communities have arrived at the phrase independently, and its meaning has shifted over time. It started as "a piece of business logic" and is becoming "a governed, auditable record of a commitment." That shift is the most interesting part of the story.

## Origins

### Decision tables and rules engines

The oldest root is the decision table, a tabular way of writing business rules that dates back to early data processing and later became central to rules engines. In this tradition, a decision object is a software artifact that holds logic. Appian still uses the term this way: a decision is a design object that stores business rules in a table, matches input values against rows, and returns the corresponding outputs. The appeal is keeping complex rules in one central, readable place instead of burying them in code.

### Standardization through DMN

The Object Management Group formalized the idea of a decision as a first-class, modelable thing with the Decision Model and Notation (DMN) standard. Version 1.0 was adopted in September 2015, and the standard has been revised regularly since, with 1.5 in 2024 and a 1.6 beta published in September 2024.

DMN's core contribution was separating decision logic from process logic, designed to sit alongside BPMN process models. Its contributors were largely decision-management vendors, including FICO, IBM, Camunda, and Decision Management Solutions.

### A separate meaning in health research

In health preference research, the "decision object" is the thing being chosen, such as a treatment, device, or screening service, rather than a software artifact. Researchers describe it through attributes and levels in order to measure how people value it. If you encounter the term in a medical or survey-design context, this is likely the intended meaning.

### Related idea: Architecture Decision Records

In software engineering, Architecture Decision Records (popularized around 2011) treat design choices as versioned documents with context and consequences. They don't use the phrase "decision object," but they share the same instinct of making decisions durable and reviewable.

## The Agentic AI Turn

### Context graphs and decision traces

The concept gained new life in the AI-agent conversation after Foundation Capital published an essay by Jaya Gupta and Ashu Garg on December 22, 2025, calling context graphs "AI's trillion-dollar opportunity."

Their argument: enterprise systems record outcomes but not reasoning. The exceptions, overrides, approvals, and precedents behind a decision live in Slack threads, calls, and people's heads. They call these missing records **decision traces**, and argue that accumulating them into a queryable **context graph** will define the next generation of enterprise software. In their framing, the previous generation of software captured what happened; the next will capture why.

The idea spread quickly. HubSpot's Dharmesh Shah described context graphs as a system of record for decisions, and Forbes covered the trend in April 2026.

### Efforts to define the object

This framing turned the decision into a durable asset that agents can query as precedent and auditors can inspect. Several groups are now working out what such an object should contain.

**Enterprise architecture.** Brillion's framework defines an *Enterprise Decision Object* as a governed class of determinations, recording its owner, objective, trigger, inputs, policies, rules, models, constraints, confidence, explanation, review path, outcomes, feedback, version, and audit evidence. The object is meant to stay stable regardless of how the decision is implemented, whether through rules, DMN, predictive models, optimization, human review, or a mix.

**Decision Object Theory.** A framework published in February 2026 argues that decisions should be treated as engineered objects with structure, boundaries, lifecycle states, quality metrics, dependencies, and governance, so that they can be designed, tested, audited, and versioned.

**Academic governance.** A paper posted to SSRN in August 2026 (Sean Yang, "Decision Audit") proposes treating the declared basis of a consequential decision as its own audit object, defined before the action is taken. Its central claim is that a decision can be meaningfully scrutinized without needing access to the private reasoning that produced it, a notable position given how unreliable model reasoning traces can be as evidence.

## Where It's Going

### Standards

If every agent platform records decisions in its own format, cross-system precedent queries become impossible. Commentators have called for an OpenTelemetry-style standard for decision records. Grassroots work is underway, including schema proposals on arXiv and Zenodo and an active discussion in Microsoft's agent-governance-toolkit repository. One unsolved problem raised there is decision identity: resolving a decision's identifier across systems without depending on a single operator everyone has to trust.

### Regulation

Compliance is a strong driver. Participants in the governance discussions point out that the EU AI Act's logging and traceability requirements (Articles 12 and 19) describe something close to a decision-shaped record. As those obligations phase in, auditable decision records may shift from nice-to-have to required.

### Model-first vs. trace-first

This is the main fault line.

- **Trace-first** (the Foundation Capital camp): capture what agents and people actually do, and let structure emerge from accumulated traces.
- **Model-first** (the established decision-management camp, e.g. FlexRule): define decisions explicitly first. Traces only describe what happened inside a decision boundary; without a model, there's nothing meaningful to trace and governance becomes an afterthought.

Neither side has solved **precedent decay**: knowing when a past decision stops being a valid guide. Foundation Capital acknowledges there's no obvious rule for this. A discount exception approved under a previous CFO may not apply today.

### Likely outcome

The most plausible path is a synthesis. DMN-style models define what a decision *should* be, trace records capture what actually happened, and the decision object becomes the schema linking the two. Whether that schema becomes an open standard or a proprietary moat held by whoever sits in the agent's execution path is probably the biggest commercial question in this space.

## Sources

- Appian documentation, Decision Object: https://docs.appian.com/suite/help/26.8/Decisions.html
- OMG, DMN specification and version history: https://www.omg.org/spec/DMN/1.5
- Calvanese et al., "Semantic DMN" (2018): https://arxiv.org/pdf/1807.11615
- "How to Present a Decision Object in Health Preference Research" (PMC): https://pmc.ncbi.nlm.nih.gov/articles/PMC12170727/
- Foundation Capital, "AI's trillion-dollar opportunity: Context graphs" (Dec 2025): https://foundationcapital.com/ideas/context-graphs-ais-trillion-dollar-opportunity
- Foundation Capital, "Context graphs, one month in" (Jan 2026): https://foundationcapital.com/ideas/context-graphs-one-month-in
- Forbes, "VCs Say Context Graphs Might Be The Next Big Thing In AI" (Apr 2026): https://www.forbes.com/sites/josipamajic/2026/04/03/vcs-say-context-graphs-might-be-the-next-big-thing-in-ai/
- Graphlit, "The Context Layer AI Agents Actually Need": https://www.graphlit.com/blog/context-layer-ai-agents-need
- Brillion, Enterprise Decision Object: https://www.brillion.africa/edaf/enterprise-decision-object
- Regen AI Institute, Decision Object Theory (Feb 2026): https://regen-ai-institute.com/decision-object-theory/
- Yang, "Decision Audit: The Decision as an Auditable Object in Agentic AI Governance" (SSRN, Aug 2026): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7367698
- Microsoft agent-governance-toolkit, Discussion #276: https://github.com/microsoft/agent-governance-toolkit/discussions/276
- FlexRule, "Stop thinking decision traces solve your agentic AI problem" (Jan 2026): https://www.flexrule.com/daily-insight/stop-thinking-decision-traces-solve-your-agentic-ai-problem/
