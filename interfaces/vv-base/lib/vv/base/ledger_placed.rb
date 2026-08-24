# frozen_string_literal: true

require "active_support/concern"

module Vv
  module Base
    # A canonical intent home carries a ledger placement.
    # private_local NEVER crosses a CPCP PULL boundary — callers get
    # canonical/sync_intent only. (gstack review fix #1)
    #
    # Semantics are unchanged from the mind-pod concern: `.all` still
    # includes private_local (BACK must see it in-process). PULL adapters
    # must use `.cross_boundary` or `Vv::Base::Pull.relation`. Default
    # scope was rejected: it would hide private_local from the writer.
    module LedgerPlaced
      extend ActiveSupport::Concern
      PLACEMENTS = %w[canonical sync_intent private_local].freeze

      included do
        validates :ledger_placement, inclusion: { in: PLACEMENTS }
        scope :cross_boundary, -> { where.not(ledger_placement: "private_local") }
      end
    end

    # Named PULL API. Makes the boundary a method you call, not a scope
    # you have to remember. Does not change `.all`.
    module Pull
      module_function

      def relation(klass)
        unless klass.respond_to?(:cross_boundary)
          return { ok: false, reason: :not_ledger_placed,
                   because: "#{klass} does not include Vv::Base::LedgerPlaced" }
        end
        { ok: true, relation: klass.cross_boundary }
      end
    end
  end
end
