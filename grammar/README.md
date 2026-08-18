# grammar/  🟢 OWN IT

**The durable language.** This is the most-owned part of the stack — the stable,
versioned contract layer that everything else derives from. When code and
contract disagree, the contract wins.

| Subdir | Purpose | Canonical source |
|---|---|---|
| `osi-level-8/` | OSI Level 8 normative spec, profiles, and closed SHACL shapes — the grounding language. | [laquereric/osi-level-8](https://github.com/laquereric/osi-level-8) |
| `cpcp/` | Cyborg-Pod-Contract-Package: the `/_cpcp` contract profile. | CPCP normative spec (with `rails-cpcp`) |
| `conformance/` | Profile 1–8 conformance tests — valid and invalid example calls. | this repo |

## Why grammar is first-class

OSI Level 8 translates upstream AI capabilities into enterprise actions via
**Context** (what may be read) and **Effect** (what may be done), constrained by
**closed SHACL shapes**. Because the contract is stable and machine-validated,
downstream experimentation stays auditable and governable while upstream churns.
