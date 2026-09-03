# Gap 98: catalog IRI and TTL NodeShape IRI

Named by the gap-22 inventory and still true until this gate: no
checker compared `ProfileCatalog::Entry#shape_iri` to the TTL
`sh:NodeShape` IRI. Binding and resolution key by local name. Drift
canons `sh:path` to a local token. `check_iri_namespaces` baselines
catalog literals and `@prefix` IRIs **separately**, so each can match
its own baseline while the two disagree.

Did not rename `osi.example`. Row 22 stays the owner's namespace ADR.

## What is compared

The live identity is the full IRI. Grounding copies `entry.shape_iri`
onto `Result#shape_id`. A catalog IRI change that keeps the local
name, or a `@prefix` change that keeps local names, used to pass
every gate.

The join:

1. Literal `SHAPE_MAP` / `L8_PROTOCOL_MAP` rows (gem, TTL file, IRI).
2. `p9_operation_shapes` / `p11_operation_shapes`, which must still
   construct `VOCAB_IRI + local` from the named shape-gem TTL.
3. Each TTL file those entries resolve: expand `@prefix` + local
   (or a `<>` IRI) to a full NodeShape IRI.
4. Catalog IRI must equal one of those. Same local name, different
   full IRI is `IRI DIVERGENCE`. Missing local name is
   `CATALOG IRI ABSENT FROM TTL`.

TTL NodeShapes in those files that the catalog does not name are
not this gate (quarantine / binding already count disk).

## Population

87 catalog entries, 90 NodeShapes, 6 TTL files. 0 examined is not
a pass. Empty `CHECK_ROOT` fails.

The 87 is the live catalog (16 `SHAPE_MAP` + 13 `L8_PROTOCOL_MAP` +
P9/P11 operation generators). The extra 3 NodeShapes live in the
L8 P11 bundle next to the 13 protocol shapes.

## Plants

`tooling/shacl/plant_catalog_ttl_iri.py`. Does not leave files behind.

| plant | want |
|---|---|
| clean tree | exit 0 |
| empty `CHECK_ROOT` | exit 1 |
| empty tree | exit 1 |
| catalog IRI `https://osi.example/shapes/P1NoteCreateEffectShape` → `https://example.invalid/shapes/P1NoteCreateEffectShape` (local name unchanged) | `IRI DIVERGENCE` |
| `@prefix osi:` in profile-1 TTL retargeted the same way | `IRI DIVERGENCE` |

## What this is not

- Not the namespace ADR (row 22). `osi.example` stays.
- Not a rewrite of binding/resolution/drift to key by full IRI.
  Those gates keep their local-name contracts; this one is the join.
- Not a baseline of catalog literals. That is still
  `check_iri_namespaces.py`. Updating that baseline without updating
  the TTL (or the other way) is what this gate is for.

0044 names the checker in `enforced_by`. The catalog is the resolution
mechanism that ADR already decided; the IRI it copies onto
`Result#shape_id` is the identity this gate holds.
