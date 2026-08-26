---
id: "0026"
title: Profile 6 makes authorization structural evidence, never ambient permission
status: proposed
date: 2026-08-26
subject_kind: profile
subject: P6
components: [osi-level-8-profiles]
paths:
  - gems/osi-level-8-profiles/profile-6-enterprise-authorization-evidence
enforced_by:
  - gems/osi-level-8-profiles/scripts/validate.py
supersedes: null
superseded_by: null
---

## Context

Ambient permission -- the call succeeded, so it must have been allowed -- cannot
be audited, delegated accountably, or revoked with confidence. Nobody can say
which policy version permitted a specific boundary crossing, because nothing
recorded it.

## Decision

Authorization is **structural evidence**: a policy-versioned
`AuthorizationDecision` bound to a subject, an action, a resource, and the
boundary-crossing Effect it authorizes. `CredentialRef` and `Revocation`
complete the set.

A **credential reference is not a credential secret**, and the distinction is
enforced rather than advised -- the `invalid-literal-secret` fixture must fail
validation. A profile that permitted an inline secret would put credentials into
exactly the durable, portable, replicated records this layer exists to produce.

Default-deny from the base profile is preserved.

Deliberately out of scope: any particular policy language, credential format,
identity provider or cryptographic scheme.

## Consequences

- "Who authorized this, under which policy version, and is it still valid" is a
  query against records rather than a reconstruction.
- Delegation and revocation are modelled, so withdrawing authority is an action
  with evidence rather than a configuration change.
- Refusing to prescribe a policy language means integrations bring their own,
  and the evidence shape is what has to be common.
- **Proposed, not accepted.** Manus-drafted review-ready draft, no
  implementation.
