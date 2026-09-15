# frozen_string_literal: true

require "json"
require "time"
require "fileutils"
require "digest"

module RailsOsiLevel8
  # Rung 4 reader. SQL/hashes over streams that already exist, plus the R4
  # call JSONL. Output is a blob named by the digest of the report, not a
  # scrape endpoint.
  #
  # Never merges AdmissionAttempt, journal refused, and RefusalLog.
  # reversal_rate is absent, not zero. expired is not a job state.
  module LedgerReport
    module_function

    SCOPE = {
      "streams" => %w[AdmissionAttempt bpmn_bbo_run_jobs Ui::Action cpcp_calls.jsonl],
      "not" => [
        "RefusalLog merged into refusal_rate",
        "operation journal PULL",
        "pod-wide refusal percentage",
        "Ui::Action as a durable ledger"
      ],
      "methods" => "CPCP operations that return Envelope.ok through Dispatcher",
      "coverage" => "not pod-wide; unwrapped methods are out of scope"
    }.freeze

    def call(now: nil, admission_attempts: :auto, jobs: :auto, ui_actions: :auto,
             calls: :auto, writer_started_at: :auto, dir: nil)
      now = (now || clock).utc
      attempts = load_attempts(admission_attempts)
      job_rows = load_jobs(jobs)
      actions = load_actions(ui_actions)
      call_rows = load_calls(calls)
      started = load_started(writer_started_at)

      report = {
        "kind" => "ledger_report",
        "at" => now.iso8601,
        "plan" => "plan_ledger_reporting.md",
        "stages" => %w[R1 R2 R4],
        "scope" => SCOPE,
        "latency_human" => latency_human(job_rows),
        "latency_catalog" => latency_catalog(actions, job_rows),
        "open_past_due" => open_past_due(job_rows, now),
        "refusal_rate" => refusal_rate(attempts),
        "pull_push_ratio" => pull_push_ratio(call_rows, started, now),
        "reversal_rate" => absent(
          "no compensating OperationRequest that cites an original cid; " \
          "canvas undo is a new digest; cancelled/failed are siblings of completed, not undo. " \
          "Absent is not zero."
        )
      }

      checked = honest(report)
      return checked unless checked[:ok] || checked["ok"]

      # Insertion-order JSON.generate, not Cid.deep_sort: that helper
      # treats `false` as missing (`x || y`) and would drop durable:false.
      digest = "sha256:#{Digest::SHA256.hexdigest(JSON.generate(report))}"
      blob = { "digest" => digest, "report" => report }
      path = write_blob(dir, digest, blob)
      Envelope.ok(digest: digest, path: path, report: report)
    end

    # Gates as a function so a plant can hand a lying report and watch it refuse.
    def honest(report)
      r = stringify(report)
      rev = r["reversal_rate"]
      if numeric_zero?(rev) || rev == 0 || rev == 0.0
        return Envelope.fail(reason: "absent_rendered_as_zero",
                             because: "reversal_rate printed 0; absent is not zero")
      end
      unless absent?(rev)
        return Envelope.fail(reason: "absent_rendered_as_zero",
                             because: "reversal_rate must be status=absent until a reversal is an event")
      end

      rates = r["refusal_rate"]
      if rates.is_a?(Numeric) || r.key?("refusal_rate_overall") || r.key?("overall_refusal_rate")
        return Envelope.fail(reason: "rollup_forbidden",
                             because: "a pod-wide refusal percentage hides the per-scope signal")
      end
      if rates.is_a?(Hash)
        Array(rates["rows"]).each do |row|
          dir = row["direction"]
          if dir && dir.to_s != "push"
            return Envelope.fail(reason: "push_only_denominator",
                                 because: "refusal_rate included direction=#{dir}; PULL in the denominator is a sampling defect")
          end
          if row["operation_name"].to_s.empty? || row["operation_name"] == "*"
            return Envelope.fail(reason: "rollup_forbidden",
                                 because: "refusal_rate row missing operation_name (pod-wide)")
          end
        end
      end

      unless r["scope"].is_a?(Hash) && r.dig("scope", "coverage").to_s.include?("not pod-wide")
        return Envelope.fail(reason: "scope_unnamed",
                             because: "a report that implies pod-wide coverage while counting only wrapped methods fails")
      end

      ratio = r["pull_push_ratio"]
      if ratio.is_a?(Hash) && ratio["status"] != "absent"
        started = parse_time(ratio["writer_started_at"])
        window_from = parse_time(ratio.dig("window", "from"))
        if started && window_from && window_from < started
          return Envelope.fail(reason: "fabricated_history",
                               because: "pull_push_ratio window starts before the writer existed")
        end
        unless ratio["writer_started_at"]
          return Envelope.fail(reason: "fabricated_history",
                               because: "a numeric ratio without writer_started_at pretends to cover prior traffic")
        end
      end

      Envelope.ok
    end

    def latency_human(jobs)
      samples = jobs.select { |j|
        j["kind"].to_s == "user" &&
          j["element_id"].to_s == "HumanReview" &&
          j["state"].to_s == "completed" &&
          j["claimed_at"] && j["ended_at"]
      }.map { |j|
        seconds_between(j["claimed_at"], j["ended_at"])
      }.compact
      {
        "definition" => "activity.ended_at - job.claimed_at where kind=user element_id=HumanReview state=completed",
        "n" => samples.length,
        "seconds" => samples
      }
    end

    def latency_catalog(actions, jobs)
      by_id = jobs.each_with_object({}) { |j, h| h[j["id"].to_s] = j if j["id"] }
      durations = []
      with_at = 0
      actions.each do |a|
        next unless a["at"]

        with_at += 1
        next unless %w[accept reject].include?(a["action"].to_s)

        job_id = a.dig("job", "jobId") || a.dig("job", "job_id") || a["jobId"]
        job = by_id[job_id.to_s]
        next unless job && job["claimed_at"]

        sec = seconds_between(job["claimed_at"], a["at"])
        durations << sec if sec
      end
      {
        "status" => "process_lifetime",
        "because" => "Ui::Action.at exists; the log dies with BACK. Not a ledger (R3).",
        "durable" => false,
        "n_with_at" => with_at,
        "durations_seconds" => durations
      }
    end

    def open_past_due(jobs, now)
      user = jobs.select { |j| j["kind"].to_s == "user" }
      openish = user.select { |j| %w[open claimed].include?(j["state"].to_s) }
      past = openish.select { |j|
        due = parse_time(j["due_at"])
        due && due < now
      }
      share = openish.empty? ? nil : (past.length.to_f / openish.length)
      {
        "definition" => "operator: kind=user AND state in (open,claimed) AND due_at < now. " \
                        "The engine does not expire; this is not a JOB_STATES value.",
        "n" => past.length,
        "open_or_claimed" => openish.length,
        "share" => share
      }
    end

    def refusal_rate(attempts)
      push = attempts.select { |a| a["direction"].to_s == "push" }
      by_op = push.group_by { |a| a["operation_name"].to_s }
      rows = []
      by_op.each do |op, group|
        next if op.empty?

        total = group.length
        group.group_by { |a| a["conforms"] == false ? (a["refusal_reason"] || "unspecified") : nil }
             .each do |reason, subset|
          next if reason.nil?

          refused = subset.length
          rows << {
            "operation_name" => op,
            "refusal_reason" => reason,
            "direction" => "push",
            "refused" => refused,
            "attempts" => total,
            "rate" => refused.to_f / total
          }
        end
      end
      {
        "denominator" => "AdmissionAttempt direction=push per operation_name",
        "rows" => rows.sort_by { |r| [r["operation_name"], r["refusal_reason"]] }
      }
    end

    def pull_push_ratio(calls, started, now)
      unless started
        return absent("CallLog writer has not started; a missing file is not zero PULL or PUSH")
      end

      started_t = parse_time(started)
      counted = calls.select { |c|
        c["kind"].to_s == "call" &&
          (t = parse_time(c["at"])) && started_t && t >= started_t
      }
      pull = counted.count { |c| c["direction"].to_s == "pull" }
      push_all = counted.select { |c| c["direction"].to_s == "push" }
      push_first = push_all.count { |c| !c["replayed"] }
      push_replay = push_all.count { |c| c["replayed"] }
      methods = counted.map { |c| c["method"].to_s }.uniq.sort
      {
        "status" => "ok",
        "writer_started_at" => iso(started_t || started),
        "because" => "count starts at writer_started_at; prior traffic is not covered",
        "pull" => pull,
        "push" => push_all.length,
        "push_first" => push_first,
        "push_replay" => push_replay,
        "ratio_pull_to_push" => push_all.empty? ? nil : (pull.to_f / push_all.length),
        "methods" => methods,
        "window" => { "from" => iso(started_t || started), "to" => now.iso8601 }
      }
    end

    def absent(because)
      { "status" => "absent", "because" => because, "value" => nil }
    end

    def absent?(value)
      value.is_a?(Hash) && value["status"].to_s == "absent"
    end

    def numeric_zero?(value)
      value.is_a?(Numeric) && value.to_f == 0.0
    end

    def load_attempts(src)
      return Array(src).map { |r| stringify(row_attempt(r)) } unless src == :auto
      return [] unless defined?(AdmissionAttempt) && ar_table?("osi_l8_admission_attempts")

      AdmissionAttempt.all.map { |a| stringify(row_attempt(a)) }
    rescue StandardError
      []
    end

    def load_jobs(src)
      return Array(src).map { |r| stringify(row_job(r)) } unless src == :auto
      return [] unless defined?(::Vv::BpmnBbo::Run::Job)

      ::Vv::BpmnBbo::Run::Job.includes(:flow_node, :activity_instance).map { |j| stringify(row_job(j)) }
    rescue StandardError
      []
    end

    def load_actions(src)
      return Array(src).map { |r| stringify(r) } unless src == :auto

      Ui::Action.journal.map { |r| stringify(r) }
    rescue StandardError
      []
    end

    def load_calls(src)
      return Array(src).map { |r| stringify(r) } unless src == :auto
      return [] unless defined?(::RailsCpcp::CallLog)

      ::RailsCpcp::CallLog.calls.map { |r| stringify(r) }
    rescue StandardError
      []
    end

    def load_started(src)
      return src unless src == :auto
      return nil unless defined?(::RailsCpcp::CallLog)

      ::RailsCpcp::CallLog.writer_started_at
    rescue StandardError
      nil
    end

    def row_attempt(obj)
      return obj if obj.is_a?(Hash)

      {
        "operation_name" => obj.operation_name,
        "direction" => obj.direction,
        "conforms" => obj.conforms,
        "refusal_reason" => obj.refusal_reason
      }
    end

    def row_job(obj)
      return obj if obj.is_a?(Hash)

      {
        "id" => obj.id,
        "kind" => obj.kind,
        "state" => obj.state,
        "due_at" => obj.due_at,
        "claimed_at" => obj.claimed_at,
        "element_id" => obj.flow_node&.element_id,
        "ended_at" => obj.activity_instance&.ended_at
      }
    end

    def write_blob(dir, digest, blob)
      return nil if dir.nil? || dir.to_s.empty?

      FileUtils.mkdir_p(dir.to_s)
      # Colon in sha256:hex is legal in this tree's tmp; keep the digest as the name.
      path = File.join(dir.to_s, "#{digest}.json")
      File.write(path, JSON.pretty_generate(blob))
      path
    rescue StandardError
      nil
    end

    def ar_table?(name)
      defined?(::ActiveRecord::Base) && ActiveRecord::Base.connected? &&
        ActiveRecord::Base.connection.data_source_exists?(name)
    rescue StandardError
      false
    end

    def clock
      RailsOsiLevel8.config.clock.call
    end

    def parse_time(value)
      return nil if value.nil?
      return value.utc if value.respond_to?(:utc)
      return Time.parse(value.to_s).utc if value.to_s != ""

      nil
    rescue ArgumentError
      nil
    end

    def seconds_between(from, to)
      a = parse_time(from)
      b = parse_time(to)
      return nil unless a && b

      b - a
    end

    def iso(value)
      t = parse_time(value) || value
      t.respond_to?(:iso8601) ? t.iso8601 : t.to_s
    end

    def stringify(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
      when Array then obj.map { |v| stringify(v) }
      else obj
      end
    end
  end
end
