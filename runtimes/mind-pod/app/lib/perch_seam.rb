# frozen_string_literal: true

require_relative "actor_binding"

# The perch.* face. Schema is gems/vv-perch; this file is the CPCP face on
# BACK (ADR 0056). Same split as bpmn_seam.rb.
#
# O1: T4 restatement and ReleaseGroup#release! reuse ActorBinding — no
# second identity path. Fail closed when the roster is absent.
class PerchSeam
  def initialize(bearer: nil)
    @bearer = bearer
  end

  def call(method, params)
    params = params || {}
    case method
    when "perch.slice.size" then size(params)
    when "perch.slice.status" then status(params)
    when "perch.slice.restate" then restate(params)
    when "perch.freeze.cascade" then cascade(params)
    when "perch.orphan.open" then open_orphans
    when "perch.signal.report" then signal_report(params)
    when "perch.release" then release_group(params)
    else
      fail_with(400, "unknown_operation", { "method" => method, "known" => self.class.methods_known })
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    fail_with(503, "perch_tables_missing", { "because" => e.message.to_s[0, 200] })
  end

  def self.methods_known
    %w[perch.slice.size perch.slice.status perch.slice.restate
       perch.freeze.cascade perch.orphan.open perch.signal.report perch.release]
  end

  private

  def size(params)
    uc, bad = find_use_case(params)
    return bad if bad

    findings = uc.slices.flat_map { |s| s.wholeness_findings.map { |f| finding_row(f) } }
    floors = findings.select { |f| f["tier"] == "floor" && f["status"] == "fail" }
    unless floors.empty?
      return fail_with(409, floors.first["test_key"], { "findings" => floors })
    end

    ok("use_case" => uc.uc_id, "findings" => findings, "advisory" => uc.slices.all?(&:advisory?))
  end

  def status(params)
    s, bad = find_slice(params)
    return bad if bad

    sig = s.outward_signals.map { |sig| { "maturity" => sig.maturity.to_s, "source" => sig.source } }
    ok(
      "slice_key" => s.slice_key,
      "gate_passed_at" => s.gate_passed_at&.iso8601,
      "released_at" => s.released_at&.iso8601,
      "ready_waiting_on_group" => s.ready_waiting_on_group?,
      "done" => s.done?,
      "advisory" => s.advisory?,
      "needs_envelope" => s.needs_envelope?,
      "signals" => sig
    )
  end

  def restate(params)
    bound, bad = bind_actor(params["actor_id"])
    return bad if bad

    s, bad = find_slice(params)
    return bad if bad

    out = s.restate!(aim: params["aim"], receiver: params["receiver"], actor_id: bound.actor_id)
    return fail_with(409, out[:reason], { "because" => out[:because] }) unless out[:ok]

    ok("slice_key" => s.slice_key, "restated_by_id" => bound.actor_id)
  end

  def cascade(params)
    id = params["freeze_id"]
    freeze = Vv::Perch::Freeze.find_by(id: id)
    if freeze.nil?
      return fail_with(404, "no_such_freeze", { "freeze_id" => id })
    end

    above = Vv::Perch::Freeze.cascade_from(freeze)
    ok(
      "freeze_id" => freeze.id,
      # Two costs, two objects (§5.3). The record is what the climber accepted
      # and is never recomputed; the price is what a change would cost NOW.
      # Returning only the first is how F5 becomes a memo.
      "cost_shown_at_climb" => freeze.cost_shown,
      "price_now" => freeze.price_now,
      "current_cascade" => above.map { |f| { "id" => f.id, "rung" => f.rung, "subject_ref" => f.subject_ref } }
    )
  end

  def open_orphans
    rows = Vv::Perch::Orphan.where(status: [nil, "open"]).map do |o|
      {
        "id" => o.id,
        "kind" => o.kind,
        # §11.1: a boundary to question is escalated, not scheduled. A caller
        # that treats it as a dependency to manage is managing it harder,
        # which is the wrong answer -- so the two are distinguishable here.
        "questionable" => o.questionable?,
        "rank_together" => o.rank_together,
        # §11.2 as data. "What does this entry still owe" is a list, not a
        # judgement, and an empty list is the only thing that means managed.
        "unmet_obligations" => o.unmet_obligations,
        "managed" => o.managed?,
        # Derived from the parties' p85 cycle times; never stored, because a
        # stored offset is a plan that quietly stopped describing the work.
        "convergence" => o.convergence.transform_keys(&:to_s),
        "parties" => o.parties.map { |p|
          {
            "item_ref" => p.item_ref, "owner_team" => p.owner_team, "board" => p.board,
            "cycle_time_p85_days" => p.cycle_time_p85_days
          }
        }
      }
    end
    ok("orphans" => rows)
  end

  def signal_report(params)
    s, bad = find_slice(params)
    return bad if bad

    now = Time.now.utc
    rows = s.outward_signals.map do |sig|
      {
        "maturity" => sig.maturity(now: now).to_s,
        "delay" => sig.delay_iso8601,
        "window_readable" => sig.window_valid?,
        "readings" => sig.readings.map { |r|
          {
            "signal_class" => r.signal_class,
            # Absent is not zero: a reading inside its window has no value yet,
            # and `measured` says which of the two a null is.
            "measured" => r.measured?,
            "value" => r.value,
            "observed_at" => r.observed_at&.iso8601,
            "window_closes_at" => sig.matures_at(r)&.iso8601,
            "matured_at" => r.matured_at&.iso8601
          }
        }
      }
    end
    ok("slice_key" => s.slice_key,
       # The computed triple a caller actually branches on. `done` is three
       # columns and a clock, never a column.
       "signal_state" => s.signal_state(now: now).to_s,
       "done" => s.done?(now: now),
       "signals" => rows)
  end

  def release_group(params)
    bound, bad = bind_actor(params["actor_id"])
    return bad if bad

    key = params["group_key"].to_s
    group = Vv::Perch::ReleaseGroup.find_by(group_key: key)
    if group.nil?
      return fail_with(404, "no_such_release_group", { "group_key" => key })
    end

    out = group.release!
    return fail_with(409, out[:reason], { "because" => out[:because] }) unless out[:ok]

    ok("group_key" => key, "released_at" => out[:released_at], "n" => out[:n], "by" => bound.actor_id)
  end

  def find_use_case(params)
    id = params["uc_id"].to_s
    return [nil, missing_param("uc_id")] if id.empty?

    uc = Vv::Perch::UseCase.find_by(uc_id: id)
    return [nil, fail_with(404, "no_such_use_case", { "uc_id" => id })] if uc.nil?

    [uc, nil]
  end

  def find_slice(params)
    uc, bad = find_use_case(params)
    return [nil, bad] if bad

    key = params["slice_key"].to_s
    return [nil, missing_param("slice_key")] if key.empty?

    s = uc.slices.find_by(slice_key: key)
    return [nil, fail_with(404, "no_such_slice", { "uc_id" => uc.uc_id, "slice_key" => key })] if s.nil?

    [s, nil]
  end

  def finding_row(f)
    { "test_key" => f.test_key, "tier" => f.tier, "finding" => f.finding, "status" => f.status }
  end

  def bind_actor(supplied)
    binding = ActorBinding.from_env
    bound = binding.resolve!(@bearer)
    [binding.reconcile!(bound, supplied), nil]
  rescue ActorBinding::Error => e
    status = e.reason == "actor_override_refused" ? 409 : 401
    [nil, fail_with(status, e.reason, e.because)]
  end

  def ok(fields)
    { status: 200, json: { "ok" => true, "result" => fields } }
  end

  def missing_param(name)
    fail_with(400, "param_required", { "param" => name })
  end

  def fail_with(status, reason, because)
    { status: status, json: { "ok" => false, "reason" => reason, "because" => because } }
  end
end
