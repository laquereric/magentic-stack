https://levelup.gitconnected.com/an-slo-no-machine-can-read-is-just-slide-decoration-9b6c243f1946

An SLO No Machine Can Read Is Just Slide Decoration
SLO as a machine-readable spec, error budget as a deployment gate, an observability contract validated in CI, and a runbook with HITL gates.
Jaroslaw Wasowski
Jaroslaw Wasowski

Following
14 min read
·
16 hours ago
44






3:12 AM. An alert fires. The on-call engineer opens the runbook — last edited fourteen months ago. Three of the seven steps describe a load balancer that disappeared during a migration, and nobody updated the document when it did.

Twelve hours earlier, a fleet of agents had shipped forty changes to that same service. Each one passed every review it was given.

SRE teams spent a decade writing runbooks — and most of them already lie to whoever reaches for them next. That gap used to cost a few minutes while a human figured out what had actually changed. Today, an agent fleet ships forty changes in the time it takes to read one stale wiki page, and nobody notices the drift until that page is the only thing standing between an incident and a fix.

In the next few minutes, you’ll get the names of three artifacts — the SLO, the observability contract, and the runbook — that need to become enforceable specs before you hand production to an agent fleet. Plus the rule for exactly where the human-approval gate sits in each one.

Quick Win: Reliability Moves Ahead of Deployment
One thought worth taking with you, even if you stop reading right here: reliability stops being something a team does after a service ships, and becomes something the pipeline checks before it lets that service ship at all. Three artifacts carry that shift.

The first is the SLO. It stops being a number on a dashboard and becomes a YAML file sitting next to the service’s code, with the error budget wired directly into the pipeline as a gate — not as an agenda item for next month’s steering meeting.

The second is the observability contract: a declared, CI-validated list of signals the service must emit. A coding agent implements exactly the spec it was given, not an ounce more — so an unwritten telemetry requirement produces an invisible service.

The third is the runbook. It stops being a wiki page nobody has opened since the last outage and becomes a staged procedure — from prose, through a checklist and a script, up to an action an agent executes — with a human-approval gate wherever a step is irreversible or has a large blast radius. Never wherever the model’s confidence happens to dip.

None of these three artifacts is theory. The tooling exists today — it’s just markedly more mature for the first two than for the third.

With the argument sketched out, let’s look at what each of these artifacts actually has to contain and where the human stays in each one.

Reliability Enters the Spec: NFRs Stop Being an Appendix
When code is generated from a spec, a brutally simple rule applies: whatever the spec doesn’t list, the delivered system doesn’t have. Performance budgets, degradation scenarios, and reliability requirements have to move from an optional attachment into a mandatory section of the functional spec — exactly as mandatory as “what this feature does.”

The industry treated NFRs (non-functional requirements — the ones describing how well something works, not what it does) as a checklist that looked nice on paper, because an experienced engineer would fill in sensible defaults anyway. An agent doesn’t infer defaults from professional norms — it infers them from the spec text sitting in front of it. That’s why this stops being a matter of style and becomes a hard precondition the moment agents start shipping most of a service’s changes.

An NFR in an agent-era spec has no business being prose like “the system should be fast.” It has to read like an acceptance criterion: the service responds in under a second 98% of the time and scales horizontally at a tenfold traffic spike.

In practice, an agent-era spec carries three classes of requirements: functional (what the system does), operational NFRs (performance, compliance, security, observability), and data NFRs (quality, governance, model upkeep). The three artifacts in this piece — the SLO, the observability contract, and the runbook — are simply the middle class made operational.

There’s a genuine dispute here, and I’m not going to smooth it over. Some requirements — SLO, observability, and golden-path defaults — belong in the platform layer precisely so an agent can’t skip them. Others, like a single feature’s degradation scenario, have to live in that feature’s spec. That dividing line isn’t settled, and it comes back when we get to the observability contract.

If your team’s spec template still has “non-functional requirements” as an optional section tacked on at the end, that’s the first thing to fix — before the SLO tooling, before the CI gate. The template itself.

Press enter or click to view image in full size
Diagram showing a code deployment passing through three sequential gates labeled the SLO contract, the observability contract, and the runbook contract, drawn against a CI/CD pipeline backdrop.
Three gates every deploy has to clear in a spec-driven factory.
SLO-as-Spec: Error Budget as the Fleet’s Deployment Gate
Three acronyms worth separating once and for all. SLI is the raw measurement, SLO is your internal target for that measurement, and SLA is the contractual promise with penalties attached. The error budget is one minus the SLO — the amount of unreliability you’re allowed to spend. At a 99.9% monthly target, that’s about 43 minutes of downtime.

The industry conversation about SLOs got stuck on “what the target number should be.” That’s the easy twenty percent of the problem. The hard eighty percent is wiring that number into an automated gate with escalating consequences — and that’s exactly where almost every team stalls out.

A machine-readable SLO looks boring, and that’s the point. A declarative file in the repository next to the service’s code, with a metric comparing successful events to all events, a time window, and a threshold:

# OpenSLO — draft, not a complete manifest
kind: SLO
spec:
service: checkout-api
objectives:
- ratioMetric:
good:  { source: prometheus, query: 'sum(http_requests_total{code=~"2..|3.."})' }
total: { source: prometheus, query: 'sum(http_requests_total)' }
target: 0.999          # 99.9% — ~43 min of budget over 30 days
timeWindow: 30d        # rolling window
This file has one property no dashboard has: the pipeline can query it. A platform controller watches the repository and generates the Prometheus rules itself, so the monitoring infrastructure always mirrors what’s in Git. It also kills the most irritating class of retro question — who changed the threshold, and when.

The gate itself runs on burn rate — how fast the service is spending the budget relative to the window. The canonical thresholds from the Google SRE Workbook come in three tiers: a 14.4x burn over a one-hour window (a sudden outage, wake a human), 6x over six hours, and 1x over three days (slow drift, a ticket is enough). A high-priority alert requires both the long window and the short window to fire together, which filters out most false alarms.

In practice, the gate is rarely a binary switch. The ladder I see most often has five rungs: above half the budget, deploy freely; below ten percent, freeze non-critical changes; at zero, every ounce of effort goes into reliability. There’s a separate rung for agents in there: once the budget is dented, every machine-generated change needs human review before production.

Now for the honest part. OpenSLO is a real, open specification, but its production adoption remains unclear — more “promising standard” than settled fact; Sloth, which compiles definitions straight into Prometheus rules, is the more mature companion. None of the sources I reviewed document a case where a gate like this actually stopped an agent-generated deploy. The mechanics are proven; the application to agent fleets hasn’t been named in a public case study yet.

One more tension remains, and it shouldn’t be resolved away. Google’s own error budget policy has a built-in CTO escalation clause, even though the gate itself is mechanical. The automation and the emergency override are designed together, because the mechanism is meant to take politics out of day-to-day decisions, not strip the organization of its right to make an exception.

Something concrete for Monday morning: check whether your team’s SLO exists anywhere a machine can query it, or only on a dashboard. That one fact decides whether an error-budget gate is even possible for you.

Press enter or click to view image in full size
Diagram showing an error budget indicator connected to a deployment gate, with five zones ranging from free deployment at full budget to a hard freeze at zero.
Error budget as a loop: the burn rate decides whether the deployment gate is open.
The Observability Contract: What a Service Must Emit, Validated in CI
An agent implements exactly the telemetry the spec asked for, and nothing beyond it. An unwritten observability requirement isn’t a minor gap — it’s the difference between a service you can operate and a service that’s invisible until the first incident.

There’s one mental model that does the work here: treat telemetry like a public API. You don’t silently break your application’s API between releases, so don’t break what that application reports about itself either. That rule held when humans broke the contract through carelessness — I see no reason to lower the bar now that an agent breaks it through omission.

The anatomy of the contract is surprisingly concrete:

Identity and ownership — service name, environment, owner tag. Telemetry without an owner is useless at 3:12 AM.
Semantic consistency — an operation name like POST /orders/{id}, not a raw URL with a pasted-in identifier that shatters metric aggregation.
Cross-signal correlation — logs for a traced request must carry trace_id and span_id, so they can be stitched back to the trace.
Forbidden attributes — authorization headers, session tokens, and email addresses. A filter, not a recommendation.
Cardinality limits — hard barriers against unbounded sets of label values.
The number of enforcement points matters: there are two, not one. At build time, a linter compares the instrumentation manifest against the telemetry registry and fails the build before the container even exists. At runtime, an OpenTelemetry collector normalizes attributes, redacts sensitive data, and quarantines any stream that violates the contract. The first point guards against a mistake in the code; the second guards against a mistake in the assumptions.

The reason cardinality limits belong in the contract is financial. Cardinality explosion — a metric label like a request identifier turning every event into its own time series — quietly multiplies storage and query costs. The loudest publicly documented case is Coinbase’s roughly $65 million Datadog bill for 2021 (disclosed by Gergely Orosz), which ended in a renegotiated contract — after Coinbase built a parallel Grafana/Prometheus/ClickHouse stack and came close to migrating off entirely. That’s the price of leaving one line out of the spec.

This is where the dispute from the first section comes back, in its sharpest form. One school builds the contract around system health — CPU saturation, memory, and throughput. The other argues that in a distributed architecture, what matters is the health of a single event and a single user path. Nobody experiences eighty percent CPU utilization — they experience an error and a load time.

My own call, and I’m treating it as an opinion, not a settled fact: cardinality limits and sensitive-data filters are platform defaults, because they’re identical for everyone. Which business paths get deep tracing is a decision for that specific feature’s spec. That line separates cost from intent.

Today’s test: check whether one service’s telemetry requirements exist as a versioned, reviewable artifact. If the only place “what this service should log” lives is one engineer’s memory, a code-generating agent has no way to find out.

Press enter or click to view image in full size
Infographic showing a service’s telemetry checked against five contract requirements, both at the CI build gate and at the runtime collector, with a reject path and a pass path.
Infographic showing a service’s telemetry checked against five contract requirements, both at the CI build gate and at the runtime collector, with a reject path and a pass path.
The Runbook as an Executable Spec: The Gradient and the HITL Gates
A runbook isn’t a document. A runbook is a maturity level, and the gradient has four rungs.

The first rung is wiki prose — it rots immediately, because nobody updates it in step with the code. The second is a parameterized checklist, where the on-call engineer swaps in cluster names and pastes commands into a terminal. The third is an executable script: a human still decides whether to run it, but the remediation logic is already deterministic. The fourth is a spec executed by an agent, which detects the anomaly, picks the procedure itself, and runs it inside a policy envelope defined in advance.

The lower you sit on that ladder, the worse your response time and maintenance cost get.

Now for the part the industry doesn’t love to say out loud. Most teams sit on rung two or three today, not four. Even the most mature commercial “AI SRE” products stop execution at human approval by design — that’s how the product was built. Anyone selling you a fully closed operational loop today is selling a roadmap, not a deployment.

The rule that follows from this is short: the HITL gate — the point where the pipeline stops and waits for a named human’s approval — sits at the intersection of irreversibility and blast radius, meaning the reach of the damage a failed action could cause. Never at the model’s confidence threshold.

Two examples that show this axis clearly:

Restarting a stateless pod. Technically irreversible, but the blast radius is microscopic. An agent does this autonomously and just logs the action to the audit trail.
Dropping an index on the production database. Irreversible and with an enormous blast radius. The agent prepares the exact command, simulates its execution plan, calculates the impact on load — and stops at a gate with a binary “approve / reject.”
Why this axis, and not model confidence? Agents trained to maximize accuracy converge on an “always escalate” policy that looks safe on paper and fails exactly the tasks where the system needed to be rescued by judgment. A model that’s confident and wrong is more dangerous than a model that hesitates. The consequence category is stable; the confidence level isn’t.

This isn’t hypothetical caution. A DNS automation failure at one of the largest cloud providers in October 2025, and a cascade triggered by an automated remediation job at another one in February 2026 share the same shape: automation didn’t reduce the outage — it amplified it.

The first provider fixed a concurrency bug in its DNS system, added a rate-control mechanism for load balancers, and expanded testing and throttling for compute instances. The second halted all remediation automation and introduced manual review before restoring services in a controlled order. I’ll admit these two cases changed my mind — I used to treat HITL gates as a compliance cost, not as a piece of resilience architecture.

An executable runbook has one advantage a wiki page never had: you can rehearse it. A dry run at every significant system change is the only answer I know to the question of how to keep a procedure from going stale.

Press enter or click to view image in full size
Diagram of a four-rung runbook maturity ladder from prose to agent execution, with two example incidents branching off the top rung — one executed automatically and one stopped at a human-approval gate.
The runbook gradient and two paths at the top rung: automatic execution and a stop at the HITL gate.
The Agent-Era IDP: A Golden Path for a Client That Isn’t Human
When an agent becomes a full-fledged client of the internal developer platform — the agent-era IDP — the platform team’s product stops being a portal with good documentation and becomes an API surface that mechanically rejects non-compliant requests. An interface a human can work around a rule gap with is useless for a client that has nothing to work around it with.

An agent doesn’t click through a wizard. It calls a narrow set of approved tools — “provision cache,” “create service” — instead of getting raw access to the entire cloud API. You don’t hand an agent bare infrastructure access and wish it luck.

This is where the whole argument closes. When an agent opens a pull request for a new service, an automated policy-as-code check verifies that the template includes an initialized instrumentation block and wired-up permissions — and if it doesn’t, it rejects the request without a human in the loop. The same mechanism blocks a skipped observability contract just as effectively for a harried engineer racing a weekend deadline.

This is the most underrated side effect of the whole shift. Supporting agents isn’t about bolting a new mode onto the platform — it’s about making every reliability requirement structurally impossible to skip, which quietly improves the experience for humans too.

This pattern repeats across many organizations that scaled their architecture to dozens of microservices handling heavy traffic. A centralized, manually operated observability configuration stops scaling, and the solution that keeps recurring is handing observability-as-code back to product teams — the platform has to become declarative instead of headcount-staffed, rather than remaining a centralized bottleneck.

One last empirical anchor, deliberately left without a tidy resolution. The 2024 DORA report found that a twenty-five-percent rise in AI adoption was accompanied by roughly a seven-percent drop in delivery stability — correlation, not causation. A year later, the 2025 report put AI adoption at 90%, up 14 percentage points year over year. A faster human review doesn’t close that gap — enforced gates do.

If your platform team’s roadmap doesn’t have a line item this quarter for “what an agent calls instead of a human clicking,” that’s exactly where the next uncontrolled deployment will leak through.

Press enter or click to view image in full size
Diagram showing a human and an AI agent as two parallel clients of the same internal developer platform, both passing through a single shared policy gate before reaching production.
The same gate for two platform client types: a human through the UI, an agent through the API.
Key Takeaways
Let’s go back to 3:12 AM for a moment. In a factory where these three contracts are enforced specs, that night looks different. The deploy that caused the drift either never ships, because the budget was exhausted, or shows up in telemetry within minutes. The stale runbook steps would have surfaced at the last dry run, not live in the middle of an incident.

Four things to take with you:

An SLO works as a control mechanism only once it’s a file the pipeline can query, with the error budget wired into a real deployment gate. A slide reviewed monthly is not a control mechanism.
An observability contract, enforced both at build and at runtime, is the only thing standing between an agent-generated service and total invisibility — because an agent won’t add instrumentation the spec didn’t ask for.
The runbook gradient is real, but most teams sit a rung or two below full agent execution. HITL gates belong at the intersection of irreversibility and blast radius, never at the model’s confidence threshold.
The platform team’s product changes from a documentation portal into an API surface that mechanically rejects non-compliant requests — for an agent exactly as much as for a human.
Honestly, about the limits of this knowledge: there’s no documented case of the gate described here actually stopping an agent-generated deploy, and broad adoption of open SLO standards remains unclear. The mechanics of each piece are proven individually; their combination is where teams stand today.

Three audit questions for this week, applied to one of your services. Does our SLO exist anywhere a machine can query it? Does the telemetry requirement exist as a reviewable artifact outside one engineer’s memory? Does every irreversible step in your most-used runbook have a named HITL gate?

Press enter or click to view image in full size
Infographic showing an incident flowing through three reliability gates — SLO, observability, and runbook — sitting on the platform-as-API layer and ending in a safe-production-deploy icon.
Reliability as three gates on one platform: from incident to a safe deploy.
Closing
Thank you for the time you spent working through all three contracts — this was dense material, and I appreciate you sticking with it to the end.

If this piece changed how you think about reliability in a spec-driven factory, pass it on to someone who’s about to wire in their first error-budget gate. And if your team sits on a different rung of the runbook gradient than the one I described — or you have a working gate that’s actually stopped an agent deploy — write about it in the comments. That’s exactly the gap in public data I flagged above.

And if you want to go deeper into generating infrastructure itself from specs — the layer this piece takes as a given — I’ve written about that separately.

Platform Engineering
DevOps
Artificial Intelligence
Technology
Sre
44





Level Up Coding
Published in Level Up Coding
355K followers
·
Last published 7 hours ago
Coding tutorials and news. The developer homepage gitconnected.com && skilled.dev && levelup.dev


Following
Jaroslaw Wasowski
Written by Jaroslaw Wasowski
2.3K followers
·
21 following
AI Architect. I build enterprise AI systems — RAG, agents, LLMOps — and write the production receipts, not the hype.


Following
