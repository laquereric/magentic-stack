# frozen_string_literal: true

module Vv
  module Perch
    # Table perch_methods. Not named Method — that would shadow Kernel::Method.
    class SliceMethod < Record
      self.table_name = "perch_methods"

      MODES = %w[workflow agent effect].freeze

      # O3: a production binding names a ROUTE, not a place on a disk.
      # perchv2 §5.3 binds methods to `ornith-teacher`,
      # `ornith-1.5-35b-a3b-care`, `care-eligibility-slm@2026.11.1` — a name
      # and an optional version. A path means someone pointed production at a
      # working copy, and ADR 0038 says this repo never forks.
      #
      # Stated as a grammar the ref must MATCH, not as a list of bad spellings.
      # The first cut was `include?("nooa/src")` plus one more literal, which
      # refused exactly two ways of writing it and passed `nooa/lib/x.py`,
      # `NOOA/src`, `/Users/me/fork/teacher.py` and every other checkout on
      # earth. A deny-list of two strings is not a rule, it is two examples.
      ROUTE = /\A[a-z0-9][a-z0-9._-]*(@[A-Za-z0-9][A-Za-z0-9._-]*)?\z/
      # A bare filename has no separator and would otherwise pass the grammar.
      # `teacher.py` is not a route however much it looks like a dotted name.
      SOURCE_FILE = /\.(rb|py|js|mjs|cjs|ts|tsx|rs|go|rake|ipynb|ya?ml|json|toml|sh)\z/i

      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id

      validates :name, :mode, presence: true
      validates :mode, inclusion: { in: MODES }
      validate :binding_is_a_route

      def binding_is_a_route
        ref = prod_binding_ref.to_s
        return if ref.empty?
        return if ROUTE.match?(ref) && !SOURCE_FILE.match?(ref)

        errors.add(:prod_binding_ref, Refusals::PIN_NEVER_FORK)
      end
      private :binding_is_a_route
      # No delivery boolean. Throughput is released slices (§1).
    end
  end
end
