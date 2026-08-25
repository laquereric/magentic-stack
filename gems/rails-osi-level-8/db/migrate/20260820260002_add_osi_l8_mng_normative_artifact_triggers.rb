# frozen_string_literal: true

require "digest"
require "json"

class AddOsiL8MngNormativeArtifactTriggers < ActiveRecord::Migration[8.0]
  TABLE = "osi_l8_mng_normative_artifacts"

  def up
    copy_legacy_revision_content!

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

  private

  def copy_legacy_revision_content!
    return unless table_exists?(:osi_l8_mng_definition_revisions)

    now = Time.now.utc.iso8601
    seq = 0
    select_all("SELECT cid, envelope_json FROM osi_l8_mng_definition_revisions").each do |row|
      env = row["envelope_json"]
      env = JSON.parse(env) if env.is_a?(String)
      next unless env.is_a?(Hash)

      content = env["content"]
      next if content.to_s.empty?

      digest = Digest::SHA256.hexdigest(content.to_s)
      cid = "cid:artifact:#{digest[0, 32]}"
      next if select_value("SELECT 1 FROM #{TABLE} WHERE cid = #{quote(cid)}")

      seq += 1
      envelope = { "digest" => digest, "body" => content, "sourceRevision" => row["cid"] }.to_json
      execute <<~SQL
        INSERT INTO #{TABLE} (cid, profile_id, ledger_placement, provenance_json, payload_digest, recorded_at, envelope_json, sequence, created_at, updated_at)
        VALUES (
          #{quote(cid)},
          #{quote("osi-level-8/profile-11")},
          #{quote("canonical")},
          #{quote({ "sourceRevision" => row["cid"] }.to_json)},
          #{quote("sha256:#{digest}")},
          #{quote(now)},
          #{quote(envelope)},
          #{seq},
          #{quote(now)},
          #{quote(now)}
        )
      SQL
    end
  end
end
