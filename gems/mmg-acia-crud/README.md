# mmg-acia-crud
Option-2 of `epic_acia_crud_path`: given a resolved (AR-grounded) entity model, derive the deterministic
ACIA CRUD skeleton — `form`+`action` (create/update), `table` (index), `details` (show), delete `action` —
with each `field`'s `input_type` mapped from the column type (string→text, text→textarea, integer→number,
boolean→checkbox, date→date, *_id/*_urn→select, *email→email…). The LLM then only arranges/labels/enriches;
it never invents field structure. `Mmg::AciaCrud.derive(model)` -> {create:, update:, table:, details:, destroy:, crud:}.
