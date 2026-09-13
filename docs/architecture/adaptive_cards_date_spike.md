# Adaptive Cards `Input.Date` spike (S6)

Neeman: read Adaptive Cards before designing `task.date`. This is
that read, not a dependency.

**Source:** Adaptive Cards schema 1.5 `Input.Date` (Explorer:
type `Input.Date`). A2UI 0.9.1 Basic has `DateTimeInput`. Both
are a **date control**, not `Input.Text` / `TextField` with a
format hint.

| Adaptive Cards | Constraint we keep |
|---|---|
| `type: Input.Date` | own kind, not `SemanticText` / `Input.Text` |
| `value` / `min` / `max` | `yyyy-MM-dd` (ISO date, no time) |
| `isRequired` | our information-model `required` |
| `id`, `label` | `field` name; label is presentation |
| no HTML | already forbidden in ACIA props |

**Consequence for us.** `ghis-19@1` has no date kind, so F4
refuses `datatype=date` (`date_kind_missing`) rather than
compiling to text. S6 is a **catalog version bump**:

- `ghis-19@1` — 19 kinds; date still refuses
- `ghis-20@1` — adds `DateInput` only
- `ghis-21@1` — adds `Input` for string/text/integer/boolean/iri
  (Adaptive Cards `Input.Text` / `Input.Number` / `Input.Toggle`).
  Date stays `DateInput`, never `Input`.

Do not edit `ghis-19@1` in place. `task.date` composes
`DateInput`. A2UI emit maps DateInput → `DateTimeInput`,
Input → `TextField` (boolean → `CheckBox`).
