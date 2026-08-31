# frozen_string_literal: true

require "json"
require "fileutils"

# ADR 0052: drop admission_status. Dump first; abort if any admission-path
# row is indeterminate (neither authorized nor refused). SQLite rebuilds the
# table on column drop, so the append-only DELETE trigger must come off first.
class RemoveOsiL8AdmissionStatus < ActiveRecord::Migration[8.0]
  NOT_AN_ADMISSION = ["l8.execution.complete"].freeze

  def up
    unless column_exists?(:osi_l8_operation_requests, :admission_status)
      return
    end

    n = indeterminate_count
    write_dump(n)
    if n != 0
      raise "ADR 0052: indeterminate=#{n} — refuse to drop admission_status"
    end

    execute "DROP TRIGGER IF EXISTS osi_l8_operation_requests_no_update;"
    execute "DROP TRIGGER IF EXISTS osi_l8_operation_requests_no_delete;"
    remove_column :osi_l8_operation_requests, :admission_status
    execute <<~SQL
      CREATE TRIGGER IF NOT EXISTS osi_l8_operation_requests_no_update
      BEFORE UPDATE ON osi_l8_operation_requests
      BEGIN
        SELECT RAISE(ABORT, 'osi_l8 append-only: UPDATE forbidden on osi_l8_operation_requests');
      END;
    SQL
    execute <<~SQL
      CREATE TRIGGER IF NOT EXISTS osi_l8_operation_requests_no_delete
      BEFORE DELETE ON osi_l8_operation_requests
      BEGIN
        SELECT RAISE(ABORT, 'osi_l8 append-only: DELETE forbidden on osi_l8_operation_requests');
      END;
    SQL
  end

  def down
    add_column :osi_l8_operation_requests, :admission_status, :string
  end

  private

  def indeterminate_count
    return 0 unless table_exists?(:osi_l8_operation_requests)
    return 0 unless table_exists?(:osi_l8_operation_journal_entries)

    quoted = NOT_AN_ADMISSION.map { |n| connection.quote(n) }.join(", ")
    sql = <<~SQL
      SELECT COUNT(*) FROM osi_l8_operation_requests r
      WHERE r.operation_name NOT IN (#{quoted})
        AND NOT EXISTS (
          SELECT 1 FROM osi_l8_operation_journal_entries j
          WHERE j.operation_request_cid = r.cid AND j.event_kind = 'authorized'
        )
        AND NOT EXISTS (
          SELECT 1 FROM osi_l8_operation_journal_entries j
          WHERE j.operation_request_cid = r.cid AND j.event_kind = 'refused'
        )
    SQL
    select_value(sql).to_i
  end

  def write_dump(n)
    payload = {
      "adr" => "0052",
      "dumped_at" => Time.now.utc.iso8601,
      "indeterminate" => n,
      "gated" => (n == 0)
    }
    dir = dump_dir
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "0052-drop-gate.json"), JSON.pretty_generate(payload) + "\n")
  end

  def dump_dir
    if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
      Rails.root.join("db", "dumps").to_s
    else
      File.expand_path("../dumps", __dir__)
    end
  end
end
