https://medium.com/towards-artificial-intelligence/your-llm-needs-a-map-f145583abf61


Your LLM Needs a Map!
Before I built the chatbot, I built the map. Here is how I turn three messy databases into one graph an LLM can actually reason about.
venkatesh babu sekar
venkatesh babu sekar

Follow
11 min read
·
18 hours ago
10


1





Part 2 of 4 on building a conversational analytics engine. ~9 min read.

Point a language model at a raw database schema and ask it a real business question.

Watch it guess.

It sees Sales.SalesOrderHeader, Person.BusinessEntity, and three hundred columns named things like rowguid and TerritoryID. It has no idea that "customer" is one table, "orders" is another, and the two connect through a key it would never find on its own. So it invents a join. The SQL runs. A number comes back.

The number is wrong, and nobody notices.

That single failure mode, the confident wrong answer, is the reason this whole system exists. In Part 1, I called it the most dangerous of the seven walls that break text-to-SQL on real data. This article builds the first half of the fix.

And it is why I spent most of my time not on the chatbot, but on the unglamorous thing that comes before it: a metadata map I call the domain graph.

TL;DR

information_schema tells an LLM the shape of your data. It says nothing about the meaning. Meaning is the whole game.
I build a domain graph offline: introspect the databases, enrich the schema with an LLM once, store the result as a graph plus a vector index.
The graph holds metadata only. The actual rows never move. Queries run in place.
The payoff: at runtime, the hard thinking is already done and frozen, so answers are fast, reproducible, and safe.
The setup: three databases that disagree with each other
The system runs on an AdventureWorks dataset (Microsoft’s public sample, so you can verify every name here) spread across three engines:

PostgreSQL for production and purchasing
SQL Server for sales and person data
A CSV-backed store for HR
Different engines. Different SQL dialects. Different conventions. And the numbers that should worry you:

Tables: 71
Columns: 472
Foreign keys actually declared: 44
That last row is the problem in miniature. Real databases are full of relationships that live in someone’s head and in the application code but were never written down as constraints. The CSV source had zero declared keys, because CSV files have no constraints at all.

So when a user asks “show me orders for the customer Bike World,” the planner needs to know, reliably and ahead of time:

that “customer” and “orders” map to specific tables in a specific source,
that those tables join on a specific column,
that “Bike World” is a value it can resolve to a key,
and that the person asking is even allowed to see sales data.
None of that is safely derivable at query time by a model staring at a schema dump. All of it is derivable once, offline. That offline derivation is the domain graph build.

The whole pipeline in one picture
Press enter or click to view image in full size

Domain graph bootstrap
How to read it:

Left side, cheap and deterministic. Introspection just reads the databases.
Middle, expensive and fuzzy. The LLM enrichment runs once, offline, never on the hot path.
Right side, the artifacts. A graph (for structure) and a vector index (for meaning).
The takeaway: by the time a user shows up, the hard thinking is already done and frozen.
The rest of this article is just those five steps, in order.

Step 1: Introspection, and the attributes that actually matter
Introspection is the deterministic read of each database. One introspector per engine, all returning the same typed structure.

One rule I enforced from day one: introspectors read databases and hand back plain data. They never write to the graph. Keeping the reader and the writer separate saved me later, when the graph build became its own concern.

The leverage is in the per-column record. For every column, I keep:

name and data_type: the obvious ones
nullable: later decides whether a join is INNER or LEFT
is_primary_key / is_foreign_key
pk_source: either database or heuristic
pk_confidence: a number from 0 to 1
cardinality: distinct value count
null_percentage
sample_values: real values pulled from the column
Two of those are where a naive introspector quietly fails.

Primary keys, when the database refuses to tell you
Plenty of tables (especially the CSV ones) have no declared primary key. A planner that gives up there is useless. So when there is no database key, I score every column and pick the best candidate.

The heuristic is deliberately boring, because boring is auditable:

Exclusion gate. Throw out columns that look like keys but are not: rowguid, *_guid, *_uuid, modifieddate, *_hash, *_version, and friends.
Hard requirements. The column must be unique (distinct count equals row count) and complete (zero nulls). Fail either, rejected, no matter how key-like the name.
Score what survives:
Unique and complete: +0.70 (the base)
Identifier-style name (*id, *_id, id): +0.15
Softer pattern (*_key, *_pk, *_seq): +0.10
Integer / serial type: +0.10, UUID / string: +0.05
First column in the table: +0.05
Accept anything scoring 0.70 or higher.
An accepted guess gets pk_source = "heuristic" and pk_confidence set to its score. A declared key gets pk_source = "database" and confidence exactly 1.0.

Why I like this: it never lies about its certainty. A guessed key carries its own doubt in a field you can read downstream.

The sampling trick that finds hidden relationships
Here is the non-obvious one. For most columns I grab a capped sample. But when a column’s cardinality is low, I fetch every distinct value, not a sample.

Why pull all of them?

Those complete value sets are how I later discover the foreign keys nobody declared.
With the full set of values in a CSV column, and the full set of primary-key values in a candidate target, I can compute exactly how much they overlap.
High overlap is strong evidence of a real relationship. You cannot get that from a 5-row sample.
The introspector spends a little more on low-cardinality columns specifically to make the next step possible. Everything that comes out gets written to raw_schema.json, the contract between the deterministic world and the LLM world.

Step 2: Letting an LLM do the one thing only it can do
The schema is captured, but it is still just structure. It does not know that SalesOrderHeader is what a human means by "orders," that a salesperson calls revenue "rev," or that "last quarter" is a date range.

This is where an LLM comes in. And the single most important decision in the whole system is when.

I bring the LLM in offline, at build time. Never on the hot path for this work.

The model enriches the schema into business knowledge once, the output gets written to versioned files, and at query time everything reads those frozen files. The intelligence is precomputed. That is the trade that makes the system both smart and fast.

Several generators run in order, each feeding the next:

Relationship inference (Reads: sample-value overlaps; Produces: foreign keys nobody declared; LLM?: Yes (verified by overlap))
Entity discovery (Reads: schema + relationships; Produces: which tables are real business entities; LLM?: No (pure heuristic))
Entity analysis (Reads: discovered entities; Produces: descriptions, synonyms, name expressions, sample questions; LLM?: Yes)
Business domains (Reads: entities; Produces: groupings like HR, purchasing, production; LLM?: Yes)
Metrics catalog (Reads: numeric columns; Produces: named measures as real SQL (total revenue, AOV); LLM?: Yes)
Glossary (Reads: everything above; Produces: “last quarter,” “top,” status filters; LLM?: Yes)
A few things worth pulling out:

Relationship inference does not trust the model alone. A candidate is accepted only if the LLM’s confidence is at least 0.80 and the measured value overlap is at least 0.50. The model proposes; ground-truth overlap disposes. On this dataset that turned 40 candidates into 34 accepted relationships.
Entity discovery is deliberately not an LLM step. Deciding what your core nouns are is too important to leave to a sampling temperature. It scores tables instead: a primary join key scores 0.95, a table referenced by 3+ foreign keys scores 0.90, and so on.
Entity analysis is where the LLM earns its seat. For a person entity, it generates the name expression FirstName || ' ' || LastName. It writes the synonyms that let "client" find CUSTOMER. It drafts the sample questions a real user would ask.
The glossary stores meaning, never SQL. “Last quarter” becomes a relative date range, not a dialect-specific date function. That keeps meaning portable across three SQL engines.
The trick that makes regeneration safe
There is an operational trap hiding in all this generated config:

The LLM gets you ~90% of the way.
A human expert fixes the other ~10%.
Then you regenerate, and their work is gone.
I have watched teams “solve” this by never regenerating, and living with stale config forever. My answer is an ownership split enforced at the file level:

system_owned/ holds generated files. Treated as disposable. Delete them, rerun the build, they come back.
user_owned/ holds human corrections as small override files.
At load time, a loader reads the generated base, reads the override, and deep-merges them. The override wins on any conflict.
The payoff, from a real incident: an expert once added a couple of synonyms through an override file. Months later the entire base config got regenerated from scratch, and those synonyms simply re-merged on top, untouched. Nobody had to remember anything. That is the difference between config you can maintain and config you are afraid to touch.

Step 3: Materializing the graph
Now the build turns all that validated config into an actual graph in Neo4j. This is the heart of the article.

Press enter or click to view image in full size

Domain graph node and edge
How to read it (the four design decisions that matter):

Every node wears two labels. A table is Domain:Table, a column is Domain:Column. The first label is the layer, the second is the type. This is what lets one Neo4j database hold three graphs (domain, subject, lexical) side by side. The layer label is the namespace.
The edges carry the relationships an LLM should never invent. FOREIGN_KEY edges hold the real join key plus a confidence. ENTITY_LINK edges carry a cardinality_class (PRESERVING or MULTIPLYING) that records whether following the link fans out rows. The SQL pipeline traverses these for its joins.
Foreign keys have provenance. A single FK can come from four places (declared, inferred, cross-source, override), merged with a strict precedence, each tagged with where it came from. Deleting a wrong relationship requires a written reason, because a removed join path deserves an audit trail.
Security lives on the nodes. A table carries its access_level, its restricted_properties, whether it requires_mandatory_filter, and its row-security policies. This is the raw material the runtime uses to enforce access by rewriting SQL.
The load-bearing rule: the LLM never writes the joins. It gets them from the graph, deterministically, or the query fails loudly with “no path found” rather than hallucinating a relationship. A made-up join is a silently wrong answer, and silently wrong is the worst failure an analytics system has.

Two engineering footnotes: Neo4j properties must be flat scalars, so lists get JSON-serialized in and parsed out. And every insert is an idempotent MERGE on a stable id, so I can rerun the build over an existing graph without creating duplicates. Rebuilds are routine, not surgery.

Step 4: The semantic index, because a graph cannot read minds
The graph is perfect at one kind of question: given a concept, how does it connect? Given CUSTOMER, what table is it, how does it reach ORDERS? That is exact-key lookup and traversal.

It is hopeless at the question that actually shows up first: the user typed “orders,” so which concept did they mean? That is similarity, not traversal. A graph has no notion of “close.”

So I built a second index in Qdrant that does nothing but answer “what did this phrase most likely mean.” Six collections:

C1 semantic entities (One point is: an entity type + its description + synonyms; Queried at runtime?: Yes)
C2 semantic metrics (One point is: a named metric; Queried at runtime?: Yes)
C3 glossary (One point is: a glossary term; Queried at runtime?: Yes)
C4 columns (One point is: a single column; Queried at runtime?: Built, not yet queried)
C5 entity values (One point is: a sample value; Queried at runtime?: Built, not yet queried)
C6 vocabulary (One point is: a user’s personal alias; Queried at runtime?: Yes)
Each point is text embedded into a 1536-dimension vector (OpenAI text-embedding-3-small, cosine distance). The clever one is C1, where the embedded text is built from a template:

"{ENTITY_TYPE}: {description}. Also known as: {synonyms}. Common questions: {sample questions}"

That template is exactly why “orders” finds SALESORDERHEADER at runtime. The user's word is cosine-closest to that blob of description and synonyms, so the match happens by meaning, not by spelling. The graph then does the exact lookup to the real table.

The two stores form a pipeline, and neither can do the other’s job:

Qdrant maps language to concept. Neo4j maps concept to structure. "orders" → (similarity) → SALESORDERHEADER → (exact lookup) → Sales.SalesOrderHeader + columns + FK to Customer

Shipped vs. next: I will be straight about this, because pretending otherwise is the wrong kind of credibility. Four of the six collections are live (entities, metrics, glossary, vocabulary). Two are built on every bootstrap but not yet read (columns, entity values). They are deferred, with a note in the code. The build is cheap and wiring them in is a small, isolated change for later. If you assumed every collection was on the hot path, it is not, and I would rather tell you.

Step 5: Making the runtime never pay for any of this
When a real query runs, it does not query Neo4j for schema metadata. It reads an in-memory snapshot loaded once at startup, then served entirely from RAM.

The cache is blunt about its contract, and I wrote it that way:

Neo4j is the single source of truth. No YAML fallback.
It fails fast and loud if Neo4j is missing at startup.
After it loads, there is no per-query I/O. Every lookup is a dictionary read.
It preserves the security fields (access_level, restricted_properties), because dropping them would quietly reopen an access-control gap.
Press enter or click to view image in full size

Domain graph runtime read
How to read it:

Two read surfaces, not one. The in-RAM snapshot is the hot path. A live Cypher reader handles the rare, occasional schema lookups.
The hot path never touches the network. Schema reads happen in the tightest loops of the planner, sometimes dozens of times per question.
Why it matters: if each of those were a round-trip to the graph, every query would crawl. This one placement decision quietly determines whether the whole system feels instant or sluggish.
The rule: the graph is the source of truth and gets read in bulk at startup; the hot path reads a local snapshot. The domain graph is immutable between builds, so the snapshot never goes stale mid-session.

Key takeaways
If you build one of these, steal the sequence. The ordering is the insight.

Introspect deterministically, and keep the reader honest about its own confidence. A guessed key should carry a number that says it was guessed.
Spend your LLM budget offline. The language-to-meaning work belongs at build time, written to versioned files. An LLM in your hot path for things you could precompute is a bug, not a feature.
Separate what a machine generates from what a human corrects, and merge them at load time. It is the only way to keep config both fresh and trustworthy.
Use a graph for structure and a vector index for meaning. Let them form a pipeline, not a competition: language to concept, then concept to structure.
Put security metadata in the graph at build time, so enforcement at query time has nothing to negotiate with a language model about.
That is the map. In Part 3, I get to the part everyone actually asks about: how a plain-English question becomes a safe query end to end, how the system resolves the specific things a user names (“Bike World,” “my team”), and the one architectural line that made me comfortable putting this in front of real users with real permissions.

Next up, Part 3: From Schema to Conversation, building the subject graph and the query pipeline.

Knowledge Graph
AI
Text To Sql
Graph
Sql
10


1




Towards AI
Published in Towards AI
142K followers
·
Last published 16 hours ago
We build Enterprise AI. We teach what we learn. Join 100K+ AI practitioners on Towards AI Academy. Free: 6-day Agentic AI Engineering Email Guide: https://email-course.towardsai.net/


Following
venkatesh babu sekar
Written by venkatesh babu sekar
1 follower
·
12 following

Follow
Responses (1)
Eric Laquer
Eric Laquer
﻿

Cancel
Respond
Raf Vantongerloo
Raf Vantongerloo

17 hours ago


Hi, great article! One question though: why would you first exclude "*_uuid" as a primary key, and in the next paragraph give UUID a +0,05 modifier? Serious question, I'm not a CS engineer. I assumed UUID was always unique...
Reply
