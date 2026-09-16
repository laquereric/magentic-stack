# Entity: TierRecord

**Provided by:** `mmg-medallion`  
**Class:** `Mmg::Medallion::TierRecord`  
**Path:** `app/models/mmg/medallion/tier_record.rb`  
**Graph-backed:** yes  
**Generated:** 2026-08-03

## Description

ONE Medallion AR — table medallions, exactly Bronze/Silver/Gold (design §1). Loaded only when ActiveRecord is present. Pure Tier + Seed work offline.

## Associations

- (none declared)

## Attributes

- (schema-defined)

## Reuse

Apps needing this concept REUSE `Mmg::Medallion::TierRecord` via a thin adapter (consume, do not fork).
