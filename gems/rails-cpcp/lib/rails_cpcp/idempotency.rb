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
    def initialize
      @store = {}
      RailsCpcp.observe_not_durable!("MemoryIdempotency")
    end
    def durable?; false; end
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
          source: "rails-cpcp/idempotency",
          restoration: {
            "state_reached" => "no sqlite idempotency store",
            "inconsistency" => "operationId does not guarantee a durable receipt",
            "restore_when" => "the store initializes at the configured path",
            "restore_action" => "fix path/permissions and restart; treat in-flight operationIds as unprotected"
          }
        )
      end
    end

    def durable?; !@db.nil?; end

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
    #
    # Return value is discarded at the dispatcher. Still return `value` so a
    # caller that starts reading it does not see a raised contract. Visibility
    # is the refusal, not a new return shape.
    def put(key, value)
      unless @db
        RailsCpcp.observe_not_durable!("SqliteIdempotency#put without a handle")
        return value
      end

      @db.execute("INSERT OR IGNORE INTO #{TABLE} (key, value, created_at) VALUES (?, ?, ?)",
                  [key.to_s, JSON.generate(value), Time.now.utc.iso8601])
      value
    rescue StandardError => e
      RailsCpcp.observe_not_durable!("SqliteIdempotency#put #{e.class}: #{e.message}")
      value
    end
  end

  module_function

  def idempotency_store; @idempotency_store ||= MemoryIdempotency.new; end
  def idempotency_store=(store); @idempotency_store = store; end

  # Once per process: the store property is not a per-call failure.
  OBSERVE_NOT_DURABLE = Mutex.new
  @not_durable_observed = false

  def reset_not_durable_observation!
    OBSERVE_NOT_DURABLE.synchronize { @not_durable_observed = false }
  end

  def observe_not_durable!(because)
    OBSERVE_NOT_DURABLE.synchronize do
      return if @not_durable_observed
      @not_durable_observed = true
    end
    return unless defined?(::RailsCpcp::RefusalLog)

    ::RailsCpcp::RefusalLog.record(
      reason: "idempotency_not_durable",
      because: because.to_s,
      source: "rails-cpcp/idempotency",
      restoration: {
        "state_reached" => "replay cache does not outlive this process",
        "inconsistency" => "operationId can be issued twice across a container replace",
        "restore_when" => "a store whose put outlives the process is mounted",
        "restore_action" => "PERSIST names the path (rows 39/43); do not invent one here. See GAP64_65.md"
      }
    )
  end
end
