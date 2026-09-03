# frozen_string_literal: true

# A recorded next-boot placement intention: store X should bind path Y when
# its process next starts. Never applied live (ROW41 S1) — restart is
# operational (compose), not an RPC. One row per store.
class PersistPlacement < PersistRecord
  self.table_name = "persist_placements"

  validates :store, :path, :set_by, :recorded_at, presence: true
  validates :store, uniqueness: true
end
