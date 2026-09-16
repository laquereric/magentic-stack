# frozen_string_literal: true

# Stage 5. perchv2 §7.3: an envelope carries `bound_to` -- the freeze records
# and the per-method model bindings it was signed against -- and "binding to
# freeze_ids makes invalidation precise. ONLY a change to a freeze record the
# envelope depends on invalidates it."
#
# R3 keeps the SIGNATURE out of this gem. What stays is the binding, because
# that is what makes invalidation computable without holding a credential.
#
# bound_to is a text snapshot rather than a join table for two reasons. The
# fifteen-table count in plan_vv-perch.md §4 is load-bearing, and more
# importantly this is a RECORD of what was true at approval time -- the same
# object class as cost_shown_at_climb, not a live relationship. Deriving it
# live would make a newly added freeze retroactively part of an old approval.
class AddPerchEffectBindingBoundTo < ActiveRecord::Migration[7.0]
  def change
    change_table :perch_effect_bindings, bulk: true do |t|
      # The slice whose envelope this is. §7.3 envelopes are per slice.
      t.references :slice, foreign_key: { to_table: :perch_slices }

      # {"freeze_rungs": {id: rung}, "reaching_bindings": {method: route}, ...}
      t.text :bound_to
      t.datetime :bound_at
    end
  end
end
