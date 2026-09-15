# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module RailsCpcp
  # R4: count of (method, direction, at) on dispatcher SUCCESS.
  #
  # Not a journal kind. Not AdmissionAttempt. Neighbor of RefusalLog: same
  # directory, own file, own env, explicit rotate! never on the write path.
  # The count STARTS when this writer first appends. A ratio that pretends
  # to cover earlier traffic is a fabricated history.
  #
  # Never raises. A missing file is not zero calls.
  module CallLog
    module_function

    ENV_LOG = "CPCP_CALL_LOG"
    MUTEX = Mutex.new
    KEEP_GENERATIONS = 3
    STARTED_BECAUSE = "R4: PULL:PUSH count starts now; prior traffic is not covered"

    def log_path
      explicit = ENV[ENV_LOG].to_s
      return explicit unless explicit.empty?

      File.join(default_dir, "cpcp_calls.jsonl")
    end

    def default_dir
      RefusalLog.default_dir
    end

    # Envelope.ok with no nested {ok:false}. PUSH replay is traffic.
    def observe_success(env, method:, direction:, replayed: false)
      return false unless env.is_a?(Hash)

      ok = env.key?("ok") ? env["ok"] : env[:ok]
      return false unless ok == true

      result = env["result"] || env[:result]
      return false if nested_refusal?(result)

      replayed ||= result.is_a?(Hash) && (result["replayed"] == true || result[:replayed] == true)
      record(method: method, direction: direction, replayed: replayed)
    rescue StandardError
      false
    end

    def record(method:, direction:, replayed: false, at: nil)
      event = {
        "kind" => "call",
        "at" => iso(at),
        "method" => method.to_s,
        "direction" => direction.to_s,
        "replayed" => replayed ? true : false
      }
      MUTEX.synchronize do
        ensure_started_unlocked
        append_unlocked(event)
      end
      true
    rescue StandardError
      false
    end

    def calls
      path = log_path
      return [] unless File.file?(path)

      File.readlines(path, chomp: true).filter_map do |line|
        next if line.strip.empty?

        row = JSON.parse(line)
        row if row["kind"] == "call"
      end
    rescue StandardError
      []
    end

    def writer_started_at
      each_row do |row|
        return row["at"] if row["kind"] == "writer_started" && row["at"]
      end
      nil
    rescue StandardError
      nil
    end

    def rotate!(keep: KEEP_GENERATIONS)
      path = log_path
      return { "rotated" => false, "reason" => "absent" } unless File.file?(path)

      started = writer_started_at
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
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, "w") do |f|
          f.puts(JSON.generate(
            "kind" => "floor_rotated",
            "at" => Time.now.utc.iso8601,
            "dropped_lines" => lines,
            "dropped_bytes" => bytes,
            "kept_generations" => keep - 1
          ))
          f.puts(JSON.generate(
            "kind" => "writer_started",
            "at" => started || Time.now.utc.iso8601,
            "because" => STARTED_BECAUSE,
            "carried_from" => "rotate"
          ))
        end
      end
      { "rotated" => true, "dropped_lines" => lines, "dropped_bytes" => bytes }
    rescue StandardError => e
      { "rotated" => false, "reason" => e.class.to_s }
    end

    def generation_path(i)
      "#{log_path}.#{i}"
    end

    def each_row
      path = log_path
      return unless File.file?(path)

      File.readlines(path, chomp: true).each do |line|
        next if line.strip.empty?

        yield JSON.parse(line)
      rescue JSON::ParserError
        next
      end
    end

    def ensure_started_unlocked
      path = log_path
      return if File.file?(path) && File.size(path).positive?

      append_unlocked(
        "kind" => "writer_started",
        "at" => Time.now.utc.iso8601,
        "because" => STARTED_BECAUSE
      )
    end

    def append_unlocked(event)
      path = log_path
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "a") { |f| f.flock(File::LOCK_EX); f.puts(JSON.generate(event)) }
    end

    def nested_refusal?(result)
      return false unless result.is_a?(Hash)

      ok = result.key?("ok") ? result["ok"] : result[:ok]
      ok == false
    end

    def iso(at)
      t = at || Time.now.utc
      t.respond_to?(:utc) ? t.utc.iso8601 : t.to_s
    end
  end
end
