# frozen_string_literal: true

class AddOsiL8MngVerificationEvidenceTriggers < ActiveRecord::Migration[8.0]
  TABLE = "osi_l8_mng_verification_evidences"

  def up
    execute <<~SQL
      CREATE TRIGGER IF NOT EXISTS #{TABLE}_no_update
      BEFORE UPDATE ON #{TABLE}
      BEGIN
        SELECT RAISE(ABORT, 'osi_l8 append-only: UPDATE forbidden on #{TABLE}');
      END;
    SQL
    execute <<~SQL
      CREATE TRIGGER IF NOT EXISTS #{TABLE}_no_delete
      BEFORE DELETE ON #{TABLE}
      BEGIN
        SELECT RAISE(ABORT, 'osi_l8 append-only: DELETE forbidden on #{TABLE}');
      END;
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS #{TABLE}_no_update;"
    execute "DROP TRIGGER IF EXISTS #{TABLE}_no_delete;"
  end
end
