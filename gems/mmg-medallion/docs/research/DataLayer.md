from Modern Data 101 <moderndata101@substack.com>

Forwarded this email? Subscribe here for more
The Layering Obsession in Data Architecture
The myth of architectural progress through more layers and the maximalist cult of "one more"
Animesh Kumar and Travis Thompson
Aug 4


READ IN APP

What is a layer in a data system?
A layer is a boundary where something changes state: raw becomes structured, structured becomes trusted, trusted becomes served. A layer earns its place by doing something to the data that couldn’t have happened anywhere else in the chain.


Adapted from concepts shared by the Authors, curated by Modern Data 101
The problem is that most data architectures don’t stop there. Architectures keep adding layers almost like a habit. Another zone, another schema, another “gold” stacked on “silver” stacked on “bronze,” until the pipeline has fifteen hops. Layers upon layers, but no powerful impact of pivot served by any.

So before asking how many and what layers should I have, ask a better question:

What is each layer for?

Every layer in a data architecture is doing exactly one of three jobs:

it’s helping you build something,

helping someone consume something,

or helping you operate something.

And within each of those three, there’s a small, specific set of elements that actually carry the weight. Every capability, feature, or traditional “layer” converges within these “actionables.” This is pure outcome- and purpose-based layering.

Build: Layer that Creates Meaning
Building follows one pattern, however you name it:

→ understand the source → move the raw data if it isn’t already reachable → productize it.

Productise is where “building” enters the realm of “manufacturing” somewhat, because a transformed table is correct but unusable by anyone who didn’t build it.


The Build Layer to Create Meaning and Productise Data | Adapted from concepts shared by the Authors, curated by Modern Data 101
Productising closes that gap. Here’s what actually sits inside this layer:

Source metadata and lineage: schema, freshness, and quality signals gathered during “understand.” This is the evidence layer: you leave with proof the data is usable instead of assuming.

Extraction and landing logic: the batch, CDC, or streaming jobs that relocate raw data unchanged. Note the discipline here: this element never transforms. Its only job is to close the reachability gap. The moment it starts transforming, it has quietly become a different layer wearing this one’s badge.

The transform: the actual logic that turns raw rows into something with shape. Joins resolved, grains collapsed, duplicates removed. This is the first place a decision gets made, and it’s the element most often confused with “the pipeline” itself, when really it’s one component of one stage.

The semantic model: the layer’s centre of gravity. This is where a column stops being cust_seg_flg and becomes “customer segment,” where a measure is defined once (how it’s calculated, what it means, what “fresh” means for it) so that no two consumers can compute the same metric two different ways. A pipeline without a semantic model isn’t lacking a nice-to-have; it’s lacking a shared definition of truth.

The contract: the explicit promise attached to the product. Defining what schema you can depend on, what SLA governs freshness, what happens if either breaks. A contract is what turns a table into something another team is allowed to build on without asking permission first.

The access policy: who can see which rows, under what condition. Authored as part of the same object as the transform and the semantic model, because a product that’s technically correct but ungoverned isn’t a product, it’s a liability with a nice schema.

Deployed together, the transform, the semantic model, the contract, and the access policy become one thing: a data product. An object that carries its own meaning well enough that an AI agent (not just a person who already knows the tribal context) can consume it safely.

Learn more about the Build Layer

Consume: Layer that Creates Trust
Building well is necessary but not sufficient. A product nobody can find, verify, or plug into their tool is just a well-organised secret.

Consumption is three distinct jobs, and blurring them is exactly how “self-service” platforms rot.


The Consume Layer where data moves from discovery, trust development, and consequent activation | Adapted from concepts shared by the Authors, curated by Modern Data 101
The catalog (Discover): the searchable index of what exists, like products, metrics, perspectives, tagged and filterable by business, analytical, or technical use. This is the element that answers, does this exist, and did I even know to look for it.

Lineage and asset explorer (Understand): the view into a product’s inputs, outputs, models, and metrics, with the lineage traced between them, so you can see what a product contains before you query it or wire it into something else.

Trust and freshness signals: quality checks, freshness indicators, and AI-readiness scores attached directly to the product. This is the element that turns “someone probably checked this” into an actual, inspectable answer.

Activity and version history: run history, past errors, recent plan or schema changes. This is what lets you catch a product that used to be trustworthy and quietly isn’t anymore.

The governed semantic layer, queryable: the same semantic model from the build layer, now exposed for validation. Pick dimensions and measures, run the query, inspect the result, without touching raw tables directly. This is the element that makes “trust” something you can verify yourself rather than something you’re told.

Activation interfaces (Activate): BI tools, database clients, APIs and SDKs, and AI/agentic clients connecting through a governed protocol. This is the element that determines whether a trusted product actually reaches the workflow where a decision gets made, or dies one hop short of it.

If we skip the middle and jump from catalog straight to activation without lineage, trust signals, or version history in between, it ends up in a pattern organisations know too well: decisions built on a table nobody has looked at in eight months.

This layer, along with its caveats, isn’t optional since it literally creates the difference between access and trust.

Learn more about the Consumer Layer

Operate: Layer that Holds the System Upright
The Operate layer imbues integrity in both Build and Consume layers while they’re running, and this layer's work, or significance, is usually invisible (as it should be) until the moment it’s missing.


The Operate Layer manages and maintains the other layers (Build and Consume) | Adpated from concepts shared by the Author, curated by Modern Data 101
The platform/data plane: the infrastructure workloads actually run on, provisioned and kept healthy by whoever owns the platform.

Tenant administration: compute, data sources, and access grants, scoped per tenant so one team’s blast radius doesn’t become another’s incident.

Data governance at the storage layer: namespaces, schemas, and views in the underlying lakehouse or warehouse, governed independently of any single product built on top of them.

Product lifecycle ownership: readiness checks, deployment, promotion, and the authored access policies for products that are already live, not just the ones being built.

Access control: denied by default, granted explicitly, scoped to role. This single design choice is what makes every other element in every other layer trustworthy by default rather than by hope.

Observability: health signals for the platform, the plane, and individual products, watched by whoever owns that layer of the stack.

None of these elements produces data or serves a query. That’s exactly the point. Remove the semantic model and a consumer misreads a metric. Remove access control and a consumer sees something they shouldn’t.

The breakdown is silent, structural, and it shows up three layers downstream from where it actually happened, which is precisely why Operate layer has to be treated as a first-class layer.

Learn more about the Operate Layer

Final Note: Meaning & Purpose Over Decoration
The point of naming these elements isn’t to hand you a checklist to fill in. That’s just a different way of collecting layers upon layers, except now the decoration has better vocabulary.

The point is to make you ask, of every single element in every single layer, whether it’s carrying meaning or just carrying weight.

A semantic model that nobody maintains is decoration with a technical name. An access policy copied from another product without being reconsidered is decoration wearing a compliance badge. The vocabulary in this article is only useful if it sharpens your questions.

Thanks for reading Modern Data 101! Subscribe for free to receive new posts and support our work.

Subscribed
MD101 Support ☎️
If you have any queries about the piece, feel free to connect with the author(s). Or connect with the MD101 team directly at community@moderndata101.com 🧡

Author Connect 💬

Got questions? Find Animesh on LinkedIn or drop a comment below. 💬


Got questions? Find Travis on LinkedIn or drop a comment below. 💬

Animesh & Travis author frequently on Modern Data 101 alongside a growing community of Data and AI Experts who wield their pens to advance the field. Follow along or grab yours🖋

	Modern Data 101
Conversations around Modern Data challenges, solutions, and innovations.
By Animesh Kumar
From the Modern Data 101 Team ❤

If two AI systems deliver identical business outcomes, why does one cost ten times more to run? Worth figuring out before your next budget review, read this to understand it better: Lean AI: Building a Scalable AI Foundation


Access the full guide

Invite your friends and earn rewards
If you enjoy Modern Data 101, share it with your friends and earn rewards when they subscribe.
