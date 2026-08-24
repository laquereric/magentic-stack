# frozen_string_literal: true
require "digest"
require "sqlite3"
require "time"

module Vv
  module Blob
    # Blob storage in SQLite, CONTENT-ADDRESSED.
    #
    # The digest is the key, not a column beside one. Two consequences follow,
    # and both are the reason to build it this way:
    #
    #   put is idempotent   the same bytes twice is one row, not two, and the
    #                       caller gets the same name back both times
    #   the name is proof   a digest cannot drift from what it names, unlike a
    #                       local image id, which the daemon reassigns on every
    #                       build and therefore identifies nothing durable
    #
    # Never raises across the boundary: every method returns { ok: true, … } or
    # { ok: false, reason:, because: }.
    class Store
      SCHEMA = <<~SQL
        CREATE TABLE IF NOT EXISTS vv_blobs (
          digest       TEXT PRIMARY KEY,
          size         INTEGER NOT NULL,
          content_type TEXT,
          bytes        BLOB NOT NULL,
          created_at   TEXT NOT NULL
        );
      SQL

      def self.open(path:)
        new(path: path).tap(&:ensure_schema!)
      rescue StandardError => e
        Refusal.new(:store_unavailable, "#{e.class}: #{e.message}")
      end

      attr_reader :path

      def initialize(path:)
        @path = path.to_s
        @db = SQLite3::Database.new(@path)
        @db.busy_timeout = 5_000
        @db.execute("PRAGMA journal_mode=WAL")
      end

      def ensure_schema!
        @db.execute_batch(SCHEMA)
        self
      end

      # Content is addressed, so the digest is computed here and never supplied.
      # A caller that could name its own blob could lie about it.
      def put(bytes, content_type: nil)
        return refuse(:content_required, "put needs bytes; nil is not a blob") if bytes.nil?

        raw = bytes.to_s.dup.force_encoding(Encoding::BINARY)
        digest = "sha256:#{Digest::SHA256.hexdigest(raw)}"
        return { ok: true, digest: digest, size: raw.bytesize, stored: false } if has?(digest)

        @db.execute(
          "INSERT INTO vv_blobs (digest, size, content_type, bytes, created_at) VALUES (?, ?, ?, ?, ?)",
          [digest, raw.bytesize, content_type&.to_s, SQLite3::Blob.new(raw), Time.now.utc.iso8601]
        )
        { ok: true, digest: digest, size: raw.bytesize, stored: true }
      rescue StandardError => e
        refuse(:write_failed, "#{e.class}: #{e.message}")
      end

      def get(digest)
        row = @db.get_first_row(
          "SELECT digest, size, content_type, bytes, created_at FROM vv_blobs WHERE digest = ?", [digest.to_s]
        )
        return refuse(:not_found, "no blob named #{digest}") unless row

        { ok: true, digest: row[0], size: row[1], content_type: row[2],
          bytes: row[3].to_s.dup.force_encoding(Encoding::BINARY), created_at: row[4] }
      rescue StandardError => e
        refuse(:read_failed, "#{e.class}: #{e.message}")
      end

      def has?(digest)
        !@db.get_first_value("SELECT 1 FROM vv_blobs WHERE digest = ?", [digest.to_s]).nil?
      rescue StandardError
        false
      end

      # Deleting a content-addressed blob is deleting it for EVERY holder of that
      # digest, because they all name the same row. Reported so a caller cannot
      # mistake a no-op for a removal.
      def delete(digest)
        existed = has?(digest)
        @db.execute("DELETE FROM vv_blobs WHERE digest = ?", [digest.to_s])
        { ok: true, digest: digest.to_s, deleted: existed }
      rescue StandardError => e
        refuse(:delete_failed, "#{e.class}: #{e.message}")
      end

      def count
        { ok: true, count: @db.get_first_value("SELECT COUNT(*) FROM vv_blobs").to_i }
      rescue StandardError => e
        refuse(:read_failed, "#{e.class}: #{e.message}")
      end

      def digests(limit: 100)
        rows = @db.execute("SELECT digest FROM vv_blobs ORDER BY created_at DESC LIMIT ?", [limit.to_i])
        { ok: true, digests: rows.flatten }
      rescue StandardError => e
        refuse(:read_failed, "#{e.class}: #{e.message}")
      end

      def close
        @db.close unless @db.closed?
        { ok: true }
      rescue StandardError => e
        refuse(:close_failed, "#{e.class}: #{e.message}")
      end

      private

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
    end

    # Returned by Store.open when the database cannot be opened at all. Answers
    # the same never-raise contract, so a caller that ignores the failure gets a
    # refusal from the next call rather than a NoMethodError.
    class Refusal
      def initialize(reason, because)
        @envelope = { ok: false, reason: reason, because: because }
      end

      def method_missing(_name, *_args, **_kw) = @envelope
      def respond_to_missing?(_name, _priv = false) = true
    end
  end
end
