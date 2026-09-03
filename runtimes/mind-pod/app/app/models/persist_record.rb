# frozen_string_literal: true

# PERSIST database handle. Persist owns its own sqlite file on the
# `persist-data` named volume (PERSIST_DB_PATH), separate from the domain
# sqlite it places. The ledger cannot live in the file a path.set leaves
# (ROW8 section 4); this handle is how it does not.
class PersistRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :persist }
end
