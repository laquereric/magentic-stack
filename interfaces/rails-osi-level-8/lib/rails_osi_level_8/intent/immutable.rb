# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    # Append-only guard for Profile 10 INTENT entity rows.
    # Revisions insert a new CID; UPDATE/DELETE are aborted at the AR layer
    # (and denied by SQLite triggers in migration 20260819190002).
    module Immutable
      extend ActiveSupport::Concern

      included do
        before_update  { throw(:abort) }
        before_destroy { throw(:abort) }

        def readonly?
          !new_record?
        end
      end
    end
  end
end
