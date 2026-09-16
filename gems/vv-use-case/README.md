# vv-use-case

Use-Case 3.0 Essentials on a Fabric board. Overlay consumes this gem:
actors, use-case ellipses, system boundary, associations. Extract
`sharedai.uc.essentials.v1` from Fabric JSON. One-way share onto a Miro
board goes through **vv-miro** Effects — this gem does not call
`window.miro`.

Soft-depends on `vv-miro`. Does **not** depend on `vv-perch` (that gem
is schema-only for slices / freeze / orphans).

```js
VvUseCase.attach({ canvas: canvas, Fab: Fab, uid: uid, pushHistory: pushHistory });
VvUseCase.addActor();
VvUseCase.applyTemplate();
```

```ruby
Vv::UseCase.blob_get = ->(digest) { Vv::Canvas::BlobGate.get("digest" => digest) }
Vv::UseCase.miro_client = -> { Vv::Miro::Client.new }
Vv::UseCase::Cpcp.register!
Vv::UseCase::Assets.install!(Rails.root.join("public"))
```

CPCP: `usecase.extract` (PULL), `usecase.share` (PUSH, `operationId` +
`blobDigest`). Missing gem or `MIRO_ACCESS_TOKEN` refuses
`miro_unavailable` / `token_required`. Token never appears in the
envelope. Digest is the name; `graph_iri` refused.

Private. Not on rubygems.org. ADR 0038: this repo is the home.
