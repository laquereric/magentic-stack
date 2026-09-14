# front-base

Bun FRONT platform image. ADR 0072. Overlays `FROM` the digest in
`FLOOR-FRONT.json` (human pin; unpublished until a human declares it).

Ships:

- Core homepage stub (`/`): pair / bind + applications this Actor may enter
- `skeleton.js`: envelope, bind, rpc, `#taskSlot`, library picker
- 19+2 widget modules (`src/widgets/`), closed registry
- A2UI 0.9.1 KIND_MAP copy (`src/adapters/a2ui.js`)
- `vv-html-components.js` light-DOM enhancer (attribute-selected; no custom elements)

Does **not** ship a Fabric Stage. Shared AI Space overrides Stage in
the overlay. Do not start Bun FRONT by rewriting that Stage.

Rails `ROLE=front` remains a proxy-only stopgap until
`FLOOR-FRONT.json` carries a digest.
