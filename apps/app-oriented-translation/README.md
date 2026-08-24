# app-oriented-translation

**Oriented Translation** — a governed human surface for three joined functions,
designed on the OSI Level 8 datatypes.

| Function | The question it answers |
|---|---|
| **Orientation** | Where am I? What exists, what is settled, what is disputed, what may I act on? |
| **Meaning Clarification** | How does a proposed term become one the system will let me act on? |
| **Stewardship Translation** | How is the same governed meaning rendered for another audience or scope *without losing its referent*? |

## Design only

This gem carries a **design**, not an implementation. That is deliberate: the design
exists partly to stress Level 8's closed vocabularies, and it surfaced modification
proposals (`docs/l8-modifications.md`). Building before those are accepted would
prejudge them.

## It is made of existing L8 datatypes

Nothing here invents a parallel type system. The deliverables **are** L8 artifacts:

- Mission and vision are `intent:Mission` and `intent:Vision` — Profile 10 instances,
  not documents describing an app.
- Personas and actors are `intent:Persona` and `intent:Actor`.
- Journeys are `c4:Journey` composed of `ux:Flow` steps.
- **Pages are ACIA trees**, not HTML: a typed tree drawn from Profile 9's closed
  vocabulary of seventeen component kinds. HTML is a render target, never a source.
- The subject matter is Profile 11 (Meaning): `Concept`, `DefinitionRevision`,
  `SemanticAttestation`, `OperationBinding`, `SemanticActivation`,
  `ActabilityReceipt`.

Evidence comes from siblings and is referenced by IRI, never copied: Profile 5
provenance, Profile 6 authority, Profile 7 outcomes.

## Refusals are part of the product

Level 8 refuses rather than raises, and this app is largely a surface over *why you
cannot do a thing yet*. A user who tries to act on a term that is only `explorable`
meets `meaning.actability-insufficient`; one whose definition is contested meets
`meaning.definition-contested`. Those refusals belong in the journey, not in an error
channel beside it — so every page that can refuse shows its `RefusalNotice` branch.

## The invariant this app must not break

Profile 11 stores five closed dimensions and **derives** three bands —
`explorable`, `plan-eligible`, `effect-eligible` — per request. There is no band
field. A term is promoted only by adding evidence.

A UI that lets a steward "mark this executable" would defeat the profile it is built
on. Any control that appears to set a band is a bug in the design, not a feature.

## Contents

    docs/design.md            the design: mission, vision, personas, journeys, mockups
    docs/l8-modifications.md  changes to Level 8 the design surfaced

`lib/` carries the vocabularies the design is written against, so a later
implementation cannot silently drift from them.
