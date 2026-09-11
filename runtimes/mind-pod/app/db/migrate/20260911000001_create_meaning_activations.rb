# frozen_string_literal: true

# Meaning activations: weighted joins, not a stored tree
# (docs/architecture/MeaningActivations.md).
#
# ContextFrame, Meaning and Clarification stay three records. The EDGE changes.
# A foreign key stores membership as in-or-out, which is too coarse: a meaning
# is not owned by one frame, it is ACTIVATED under frames with a signed weight.
#
# So there is deliberately NO meanings.context_frame_id and NO
# clarifications.meaning_id. The path frame -> meaning -> clarification is how
# you WALK the structure; it is no longer how you STORE parenthood. A shortcut
# FK from clarification to frame would be worse still: it would let a
# clarification inhibit under a frame its meaning does not activate.
class CreateMeaningActivations < ActiveRecord::Migration[8.0]
  def change
    create_table :context_frames do |t|
      t.string :canonical_id, null: false
      t.string :title
      t.string :user_id
      t.timestamps
    end
    # SparqlFun's standard-form frame keys on this; it is an identity, not a
    # weight, and it belongs to the frame record rather than to any activation.
    add_index :context_frames, :canonical_id, unique: true

    create_table :meanings do |t|
      t.string :title
      t.text :excerpt
      t.boolean :dispute_open, null: false, default: false
      t.string :acceptance
      t.timestamps
    end

    create_table :clarifications do |t|
      t.string :title
      t.string :source
      t.datetime :source_at
      t.text :excerpt
      t.timestamps
    end

    # WEIGHT IS THE POINT. Closed interval [-1, +1], numeric -- not an enum and
    # not a boolean, because sign is first-class: inhibition is a negative
    # weight, never "delete the join".
    #
    # NO ROW IS NOT ZERO. Absence means the pair is not in the model; zero means
    # it is, and contributes nothing. Collapsing those makes "we considered this
    # and rejected it" indistinguishable from "we never looked", which is the
    # distinction this table exists to keep.
    create_table :context_frame_meaning_weights do |t|
      t.references :context_frame, null: false, foreign_key: true
      t.references :meaning, null: false, foreign_key: true
      t.decimal :weight, null: false
      t.timestamps
    end
    # One row per pair. A second weight for the same pair is a refusal, not a
    # second line to average.
    add_index :context_frame_meaning_weights, %i[context_frame_id meaning_id],
              unique: true, name: "index_cfmw_on_frame_and_meaning"

    create_table :meaning_clarification_weights do |t|
      t.references :meaning, null: false, foreign_key: true
      t.references :clarification, null: false, foreign_key: true
      t.decimal :weight, null: false
      t.timestamps
    end
    add_index :meaning_clarification_weights, %i[meaning_id clarification_id],
              unique: true, name: "index_mcw_on_meaning_and_clarification"

    # The range lives in the DATABASE as well as the model. A model validation
    # is bypassed by update_column, import, or console; the check constraint is
    # the contract, and out of range is a refusal rather than a clamp.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE TRIGGER cfmw_weight_range_insert
          BEFORE INSERT ON context_frame_meaning_weights
          FOR EACH ROW WHEN NEW.weight < -1.0 OR NEW.weight > 1.0
          BEGIN SELECT RAISE(ABORT, 'weight_out_of_range'); END;
        SQL
        execute <<~SQL
          CREATE TRIGGER cfmw_weight_range_update
          BEFORE UPDATE ON context_frame_meaning_weights
          FOR EACH ROW WHEN NEW.weight < -1.0 OR NEW.weight > 1.0
          BEGIN SELECT RAISE(ABORT, 'weight_out_of_range'); END;
        SQL
        execute <<~SQL
          CREATE TRIGGER mcw_weight_range_insert
          BEFORE INSERT ON meaning_clarification_weights
          FOR EACH ROW WHEN NEW.weight < -1.0 OR NEW.weight > 1.0
          BEGIN SELECT RAISE(ABORT, 'weight_out_of_range'); END;
        SQL
        execute <<~SQL
          CREATE TRIGGER mcw_weight_range_update
          BEFORE UPDATE ON meaning_clarification_weights
          FOR EACH ROW WHEN NEW.weight < -1.0 OR NEW.weight > 1.0
          BEGIN SELECT RAISE(ABORT, 'weight_out_of_range'); END;
        SQL
      end
      dir.down do
        execute "DROP TRIGGER IF EXISTS cfmw_weight_range_insert"
        execute "DROP TRIGGER IF EXISTS cfmw_weight_range_update"
        execute "DROP TRIGGER IF EXISTS mcw_weight_range_insert"
        execute "DROP TRIGGER IF EXISTS mcw_weight_range_update"
      end
    end
  end
end
