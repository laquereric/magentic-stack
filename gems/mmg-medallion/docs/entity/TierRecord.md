---
type: MM Entity
title: TierRecord
class: Mmg::Medallion::TierRecord
table: medallions
resource: app/models/mmg/medallion/tier_record.rb
generated:
  by: mmg-optimize/okf-entity/0.1.0
---
## Role
ONE Medallion AR — table medallions, exactly Bronze/Silver/Gold (design §1). Loaded only when ActiveRecord is present. Pure Tier + Seed work offline.

## Attributes
- `name` — string
- `rank` — integer
- `slug` — string
- `description` — text

## Relationships
(none)
