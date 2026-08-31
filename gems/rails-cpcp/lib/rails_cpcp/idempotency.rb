# frozen_string_literal: true
require "json"
require "time"

module RailsCpcp
  # Idempotency keyed by operationId. A PUSH names its intent before performing
  # it, and asking twice with the same name must not perform it twice.
  #
  # Pluggable, because where a receipt survives is a property of the deployment
  # and not of the protocol.
  class MemoryIdempotency
    def initialize; @store = {}; end
    def get(key); @store[key]; end
    def put(key, value); @store[key] = value; value; end
  end

  # A RECEIPT MUST OUTLIVE THE PROCESS THAT ISSUED IT.
  #
  # The in-memory store is per process, so recreating a container empties it and
  # the same operationId writes again. Observed: MIND proposed a reading of an
  # unchanged board, the deploy replaced the container, and the identical
  # operationId stored a second blob. Nothing was corrupted -- the content is
  # addressed by digest -- but `operationId` READ like a guarantee it was not
  # making, which is worse than not having one.
  #
  # sqlite3 directly rather than ActiveRecord: this gem depends on rails but not
  # on a database, and an idempotency store that needs a model, a migration and
  # a connection pool is a store most consumers will not mount.
  #
  # NEVER RAISES. A store that cannot be read yields "not cached", so the effect
  # proceeds -- at worst a retry duplicates, which the digest makes visible.
  # Refusing the write instead would let a broken cache take the seam down.
  class SqliteIdempotency
    TABLE = "cpcp_idempotency"

    def initialize(path:)
      require "sqlite3"
      @path = path.to_s
      @db = SQLite3::Database.new(@path)
      @db.busy_timeout = 5_000
      @db.execute("PRAGMA journal_mode=WAL")
      @db.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS #{TABLE} (
          key        TEXT PRIMARY KEY,
          value      TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      SQL
    rescue StandardError => e
      warn("cpcp idempotency unavailable at #{@path}: #{e.class}: #{e.message}")
      @db = nil
      if defined?(::RailsCpcp::RefusalLog)
        ::RailsCpcp::RefusalLog.record(
          reason: "idempotency_store_unavailable",
          because: "#{e.class}: #{e.message}",
          source: "rails-cpcp/idempotency"
        )
      end
    end

    def get(key)
      return nil unless @db

      row = @db.get_first_value("SELECT value FROM #{TABLE} WHERE key = ?", [key.to_s])
      row && JSON.parse(row)
    rescue StandardError
      nil
    end

    # INSERT OR IGNORE, not REPLACE. The first receipt for an operationId is the
    # one that answered; overwriting it would hand a later caller a different
    # answer to the same question.
    def put(key, value)
      return value unless @db

      @db.execute("INSERT OR IGNORE INTO #{TABLE} (key, value, created_at) VALUES (?, ?, ?)",
                  [key.to_s, JSON.generate(value), Time.now.utc.iso8601])
      value
    rescue StandardError
      value
    end
  end

  module_function

  def idempotency_store; @idempotency_store ||= MemoryIdempotency.new; end
  def idempotency_store=(store); @idempotency_store = store; end
end
