# frozen_string_literal: true
require "json"
require "time"
require "fileutils"

module RailsCpcp
  # ADR 0054 observer. Append-only JSONL of refusals, plus a heartbeat that
  # proves the observer ran. Never raises. A missing heartbeat is NOT the
  # same as zero refusals — that is the indeterminate rule.
  #
  # This is a NEW durable record, not the operation journal. Journal rows
  # need an operation_request_cid; many refusals (publisher, BACK down,
  # idempotency store, parse errors) have none.
  #
  # Gap 74 / ADR 0055 clause 5 / ADR 0058 ruling: the JSONL stays a local
  # floor, not an OTEL export and not an RDF graph. Existing fields map to
  # OTEL LogRecord names (see GAP74_RESTORATION.md). The only new attribute
  # key is cpcp.restoration, and it is omitted rather than half-filled.
  module RefusalLog
    module_function

    ENV_LOG = "CPCP_REFUSAL_LOG"
    ENV_HEARTBEAT = "CPCP_REFUSAL_HEARTBEAT"
    MUTEX = Mutex.new
    SCOPE_NAME = "rails-cpcp/refusal-log"
    SCOPE_VERSION = "1"
    RESTORATION_KEYS = %w[state_reached inconsistency restore_when restore_action].freeze
    # Bounded floor (rows 86/87, file-handoff sink): generations beside the
    # live file. Rotation is EXPLICIT (rotate!) -- never on the write path,
    # so gap-89's measured write behavior is unchanged.
    KEEP_GENERATIONS = 3

    def log_path
      explicit = ENV[ENV_LOG].to_s
      return explicit unless explicit.empty?
      File.join(default_dir, "cpcp_refusals.jsonl")
    end

    def heartbeat_path
      explicit = ENV[ENV_HEARTBEAT].to_s
      return explicit unless explicit.empty?
      File.join(default_dir, "cpcp_refusal_observer.json")
    end

    def heartbeat!
      MUTEX.synchronize { write_heartbeat_unlocked }
      true
    rescue StandardError
      begin
        MUTEX.synchronize { append_unlocked("kind" => "observer_failed", "because" => "heartbeat_write") }
      rescue StandardError
        false
      end
      false
    end

    def record(reason:, because:, source:, method: nil, operation_id: nil, restoration: nil)
      event = {
        "kind" => "refusal",
        "at" => Time.now.utc.iso8601,
        "reason" => reason.to_s,
        "because" => stringify(because),
        "source" => source.to_s,
        "otel.scope.name" => SCOPE_NAME,
        "otel.scope.version" => SCOPE_VERSION
      }
      event["method"] = method.to_s unless method.nil? || method.to_s.empty?
      event["operation_id"] = operation_id.to_s unless operation_id.nil? || operation_id.to_s.empty?
      rest = compact_restoration(restoration)
      event["cpcp.restoration"] = rest if rest
      MUTEX.synchronize do
        write_heartbeat_unlocked
        append_unlocked(event)
      end
      true
    rescue StandardError
      begin
        MUTEX.synchronize do
          append_unlocked("kind" => "observer_failed", "at" => Time.now.utc.iso8601,
                          "because" => "record_write", "source" => source.to_s)
        end
      rescue StandardError
        false
      end
      false
    end

    # Present with all four members, or absent. A half object is the
    # plausible-but-wrong shape: it looks restoration-grade and is not.
    def compact_restoration(restoration)
      return nil unless restoration.is_a?(Hash)

      picked = {}
      RESTORATION_KEYS.each do |key|
        raw = restoration.key?(key) ? restoration[key] : restoration[key.to_sym]
        text = raw.nil? ? "" : raw.to_s.strip
        return nil if text.empty?
        picked[key] = text
      end
      picked
    end

    # Dispatcher / controller: collect Envelope.fail AND a nested
    # {ok:false} handler hash wrapped in Envelope.ok (session_cycle.refuse).
    # Restoration is omitted here: the envelope does not name state.
    def observe_envelope(env, source:, method: nil, operation_id: nil)
      heartbeat!
      return false unless env.is_a?(Hash)

      if env["ok"] == false || env[:ok] == false
        err = env["error"] || env[:error] || {}
        return record(reason: err["reason"] || err[:reason] || "unknown",
                      because: err["because"] || err[:because],
                      source: source, method: method, operation_id: operation_id)
      end

      result = env["result"] || env[:result]
      nested = nested_refusal(result)
      return false unless nested

      record(reason: nested[:reason], because: nested[:because],
             source: "#{source}/nested", method: method, operation_id: operation_id)
    rescue StandardError
      record(reason: "observer_failed", because: "observe_envelope", source: source)
      false
    end

    def ran?
      File.file?(heartbeat_path)
    rescue StandardError
      false
    end

    def refusals
      path = log_path
      return [] unless File.file?(path)

      File.readlines(path, chomp: true).filter_map do |line|
        next if line.strip.empty?
        row = JSON.parse(line)
        row if row["kind"] == "refusal"
      end
    rescue StandardError
      []
    end

    # Explicit rotation for the file-handoff sink (rows 86/87). The live
    # file becomes generation .1 (up to KEEP_GENERATIONS kept); a
    # floor_rotated marker opens the fresh file naming what left, so a
    # drop is loud, never silent. Never raises; returns a plain result.
    def rotate!(keep: KEEP_GENERATIONS)
      path = log_path
      return { "rotated" => false, "reason" => "absent" } unless File.file?(path)

      lines = 0
      File.foreach(path) { lines += 1 }
      bytes = File.size(path)
      MUTEX.synchronize do
        File.delete(generation_path(keep)) if File.file?(generation_path(keep))
        (keep - 1).downto(1) do |i|
          src = generation_path(i)
          File.rename(src, generation_path(i + 1)) if File.file?(src)
        end
        File.rename(path, generation_path(1))
        File.write(path, JSON.generate(
          "kind" => "floor_rotated",
          "at" => Time.now.utc.iso8601,
          "dropped_lines" => lines,
          "dropped_bytes" => bytes,
          "kept_generations" => keep - 1
        ) + "\n")
      end
      { "rotated" => true, "dropped_lines" => lines, "dropped_bytes" => bytes }
    rescue StandardError => e
      { "rotated" => false, "reason" => e.class.to_s }
    end

    # Floor health for operators (no seam, no RPC -- local inspection).
    def status
      path = log_path
      gens = [path] + (1..KEEP_GENERATIONS).map { |i| generation_path(i) }
      present = gens.select { |g| File.file?(g) }
      last_at = nil
      if File.file?(path)
        File.readlines(path, chomp: true).reverse_each do |line|
          next if line.strip.empty?
          begin
            last_at = JSON.parse(line)["at"]
            break if last_at
          rescue JSON::ParserError
            next
          end
        end
      end
      { "path" => path, "exists" => File.file?(path),
        "bytes" => present.sum { |g| File.size(g) },
        "generations" => present,
        "heartbeat" => ran?, "last_at" => last_at }
    rescue StandardError
      { "path" => log_path, "exists" => false }
    end

    def generation_path(i)
      "#{log_path}.#{i}"
    end

    def default_dir
      if defined?(::Rails) && Rails.respond_to?(:root) && Rails.root
        File.join(Rails.root.to_s, "log")
      else
        File.join(Dir.pwd, "log")
      end
    end

    def stringify(value)
      case value
      when nil then ""
      when String then value
      else JSON.generate(value)
      end
    rescue StandardError
      value.to_s
    end

    def nested_refusal(result)
      return nil unless result.is_a?(Hash)
      ok = result.key?("ok") ? result["ok"] : result[:ok]
      return nil unless ok == false

      reason = result["reason"] || result[:reason] || result.dig("error", "reason") || result.dig(:error, :reason)
      because = result["because"] || result[:because] || result.dig("error", "because") || result.dig(:error, :because)
      { reason: reason || "nested_refusal", because: because }
    end

    def write_heartbeat_unlocked
      path = heartbeat_path
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.generate(
        "observer" => "rails-cpcp/refusal-log",
        "ran" => true,
        "at" => Time.now.utc.iso8601,
        "pid" => Process.pid
      ))
    end

    def append_unlocked(event)
      path = log_path
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") { |f| f.flock(File::LOCK_EX); f.puts(JSON.generate(event)) }
    end
  end
end
