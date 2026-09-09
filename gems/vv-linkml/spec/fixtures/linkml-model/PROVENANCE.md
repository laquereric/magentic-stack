# Fixtures: the LinkML metamodel, unmodified

These files are copied verbatim from `linkml/linkml-model`, branch `main`, path
`linkml_model/model/schema/`, downloaded **2026-09-08**. `meta.yaml` at commit
`35c91fb01382`; `metamodel_version: 1.11.0`.

They are here so that `spec/metamodel_conformance_spec.rb` can run the gem
against the real thing rather than against hand-written miniatures. A schema
this gem invented would only prove the gem is self-consistent.

LinkML is released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/),
a public domain waiver, which is why copying them here is unproblematic.

| File | SHA-256 |
|---|---|
| `annotations.yaml` | `ac3ddb343ed896e1327bcc5edc3ad2b90d6d2a288e4c66a14780a9a024195523` |
| `extensions.yaml` | `c48fb79aa4ad851403b169eb2bcb942127ee783b5d64267f756b96c86150d7c8` |
| `mappings.yaml` | `b1ce39b3bcb62f264f8ecd548be75d9f47a81738f6a8c4285c7f537d9a97d75f` |
| `meta.yaml` | `7f9e39fb18ab4bc034c00f37cd291fbb87f8fb1e2f36f43e566918bd56b96673` |
| `types.yaml` | `1c79b264397bec0eadb404d22e9b163458f1b889809b3b482ecc39c98743fe00` |
| `units.yaml` | `4a7d5184aa062b31196861c3df2f0047a194cd6a615dd263f06518392b521821` |

`lib/vv/linkml/metamodel/tables.rb` and `lib/vv/linkml/types/table.rb` are
generated from `meta.yaml` and `types.yaml` at these hashes. If a fixture is
refreshed, those tables must be regenerated with it or the conformance spec will
say so.
