#!/usr/bin/env ruby
# frozen_string_literal: true
#
# The sdlc half of bpmn.* behaves, through the seam, against a real database.
#
# vv-sdlc's README draws the division this probe tests: "No CPCP in this gem --
# bpmn.* registers on magentic-stack BACK (BpmnSeam), which is the sole writer
# (ADR 0056). This gem is the seed + token engine that seam calls." So every
# assertion below goes through BpmnSeam rather than calling the engine directly.
# Testing the engine would prove the engine works; testing the seam proves the
# thing a caller can actually reach works.
#
# THE INVARIANT THIS EXISTS FOR, from the gem's README:
#
#     You cannot skip HumanReview: only the current job completes.
#
# That is the whole claim of AiSDLC.md rendered as a process -- agent output is
# a confident junior who has read every textbook and worked at none of our
# companies, so review is the bottleneck ON PURPOSE. A seam that let a caller
# complete End_ok while review sat open would have removed the only thing the
# process is for, and it would look like it worked.
#
# ALSO TESTED: that starting is decided for sdlc and still REFUSED for
# everything else. bpmn.run.start used to refuse unconditionally on the grounds
# that "nothing advances a token". vv-sdlc is that engine for exactly one
# definition_key, so the refusal had to narrow rather than disappear -- a
# process with no engine still gets a row that never moves if you start it.

require "json"

ROOT = File.expand_path("../..", __dir__)
$LOAD_PATH.unshift File.join(ROOT, "gems/vv-bpmn-bbo/lib")
$LOAD_PATH.unshift File.join(ROOT, "gems/vv-sdlc/lib")
$LOAD_PATH.unshift File.join(ROOT, "runtimes/mind-pod/app/lib")

require "active_record"
require "vv-bpmn-bbo"

module Vv
  module Base
    class Actor < ActiveRecord::Base
      self.table_name = "actors"
    end
  end
end

require "vv-sdlc"
require "bpmn_seam"

CHECKS = []

def check(name, ok, detail = "")
  CHECKS << { "assertion" => name, "ok" => !!ok, "detail" => detail.to_s[0, 220] }
  ok
end

def build_schema!
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Schema.define do
    create_table :actors do |t|
      t.string :name, null: false
      t.string :role_key, null: false
      t.timestamps
    end
  end
  require File.join(ROOT, "gems/vv-bpmn-bbo/db/migrate/20260911000000_create_vv_bpmn_bbo.rb")
  CreateVvBpmnBbo.new.change
end

SEAM = nil

def call(method, params = {})
  BpmnSeam.new.call(method, params)
end

def result(r) = r[:json]["result"]

def open_job(r, element_id)
  Array(result(r)["jobs"]).find { |j| j["element_id"] == element_id }
end

def main
  build_schema!
  actor = Vv::Base::Actor.create!(name: "Reviewer", role_key: "reviewer")

  # SEEDING is its own method, not a side effect of the first start. A caller
  # that wants to know whether the definition exists should be able to ask.
  r = call("bpmn.seed_sdlc")
  check("seed-is-reachable-through-the-seam", r[:json]["ok"] == true, r[:json].to_json[0, 140])

  r2 = call("bpmn.seed_sdlc")
  check("seed-is-idempotent", result(r2)["already"] == true, r2[:json].to_json[0, 120])

  # The seeded definition is visible through the ordinary read path, which is
  # what makes it a definition rather than a private fixture.
  r = call("bpmn.definition", { "definition_key" => "sdlc" })
  ids = Array(result(r)["nodes"]).map { |n| n["element_id"] }
  check("seeded-process-is-readable", r[:json]["ok"] == true, r[:json]["reason"].to_s)
  %w[Start_1 AgentDraft AgentTests RealityTest HumanReview GwReview ObsCheck].each do |el|
    check("definition-has-#{el}", ids.include?(el), ids.inspect[0, 160])
  end

  # STARTING IS DECIDED FOR sdlc.
  r = call("bpmn.run.start", { "definition_key" => "sdlc", "business_key" => "TASK-1" })
  check("start-sdlc-is-not-refused", r[:json]["ok"] == true, r[:json].to_json[0, 160])
  inst = result(r)["process_instance_id"]
  check("start-returns-an-instance", !inst.nil?, inst.inspect)

  # The token lands on AgentDraft, not on HumanReview: the agent does the easy
  # 70% first, and review is downstream of it.
  check("first-job-is-agent-draft", !open_job(r, "AgentDraft").nil?,
        Array(result(r)["jobs"]).map { |j| j["element_id"] }.inspect)

  # AND STILL REFUSED FOR EVERYTHING ELSE. The engine boundary is the point:
  # a definition with no engine would get an instance that never moves.
  Vv::BpmnBbo::Package.find_or_create_by!(definition_key: "orders")
  r = call("bpmn.run.start", { "definition_key" => "orders" })
  check("start-non-sdlc-still-refuses",
        r[:json]["ok"] == false && r[:json]["reason"] == "bpmn_write_undecided",
        r[:json].to_json[0, 140])

  r = call("bpmn.run.start", {})
  check("start-without-a-key-refuses", r[:json]["ok"] == false, r[:json].to_json[0, 120])

  # THE WALK. Each service task completes and hands the token on.
  def advance!(inst, element_id)
    jobs = result(call("bpmn.jobs", { "process_instance_id" => inst }))["jobs"]
    job = Array(jobs).find { |j| j["element_id"] == element_id }
    return nil if job.nil?

    call("bpmn.complete", { "job_id" => job["id"] })
  end

  r = advance!(inst, "AgentDraft")
  check("draft-hands-off-to-tests", !open_job(r, "AgentTests").nil?, r[:json].to_json[0, 140])

  # AgentTests is NOT the ship gate. Completing it must not finish the
  # instance; it hands to an INDEPENDENT reality test. The gem's README is
  # explicit that agent tests are "internally coherent, not evidence".
  r = advance!(inst, "AgentTests")
  check("agent-tests-are-not-the-ship-gate",
        result(r)["state"] == "running" && !open_job(r, "RealityTest").nil?,
        r[:json].to_json[0, 160])

  r = advance!(inst, "RealityTest")
  review = open_job(r, "HumanReview")
  check("reality-test-hands-off-to-human-review", !review.nil?, r[:json].to_json[0, 160])
  check("human-review-is-a-user-task", review && review["kind"] == "user", review.inspect)

  # HUMAN REVIEW CANNOT BE SKIPPED.
  #
  # There is no job for ObsCheck or End_ok while review is open, so there is
  # nothing for a caller to complete past it. This is the invariant, tested as
  # absence rather than as a refusal: the seam does not need to say no, because
  # the token is not there to move.
  all_jobs = Array(result(call("bpmn.jobs", { "process_instance_id" => inst }))["jobs"])
  check("no-job-exists-past-review",
        all_jobs.map { |j| j["element_id"] } == ["HumanReview"],
        all_jobs.map { |j| j["element_id"] }.inspect)

  # An unclaimed review cannot be completed: the human has to take it first.
  r = call("bpmn.complete", { "job_id" => review["id"] })
  check("unclaimed-review-cannot-complete",
        r[:json]["ok"] == false && r[:json]["reason"] == "job_not_claimed",
        r[:json].to_json[0, 140])

  # Claiming requires a real Actor. A review claimed by nobody is a review that
  # did not happen.
  r = call("bpmn.claim", { "job_id" => review["id"] })
  check("claim-requires-an-actor", r[:json]["reason"] == "actor_required", r[:json].to_json[0, 120])

  r = call("bpmn.claim", { "job_id" => review["id"], "actor_id" => 999_999 })
  check("claim-requires-an-actor-that-exists",
        r[:json]["reason"] == "actor_missing", r[:json].to_json[0, 120])

  r = call("bpmn.claim", { "job_id" => review["id"], "actor_id" => actor.id })
  check("claim-succeeds-with-a-real-actor", r[:json]["ok"] == true, r[:json].to_json[0, 140])

  # ACCEPT -> ObsCheck. Observability is a gate after accept, not a comment.
  r = call("bpmn.complete", { "job_id" => review["id"], "outcome" => "accept" })
  check("accept-goes-to-obs-check", !open_job(r, "ObsCheck").nil?, r[:json].to_json[0, 160])

  r = advance!(inst, "ObsCheck")
  check("obs-check-completes-the-instance", result(r)["state"] == "completed",
        r[:json].to_json[0, 140])

  # REJECT terminates without ObsCheck. A rejected diff does not get an
  # observability pass on the way out.
  r = call("bpmn.run.start", { "definition_key" => "sdlc", "business_key" => "TASK-2" })
  inst2 = result(r)["process_instance_id"]
  %w[AgentDraft AgentTests RealityTest].each { |el| advance!(inst2, el) }
  jobs2 = Array(result(call("bpmn.jobs", { "process_instance_id" => inst2 }))["jobs"])
  review2 = jobs2.find { |j| j["element_id"] == "HumanReview" }
  call("bpmn.claim", { "job_id" => review2["id"], "actor_id" => actor.id })
  r = call("bpmn.complete", { "job_id" => review2["id"], "outcome" => "reject" })
  check("reject-terminates", result(r)["state"] == "terminated", r[:json].to_json[0, 140])
  check("reject-skips-obs-check", open_job(r, "ObsCheck").nil?, r[:json].to_json[0, 140])

  # A job that does not exist is a typed refusal, not a crash.
  r = call("bpmn.complete", { "job_id" => 999_999 })
  check("unknown-job-refuses", r[:json]["reason"] == "job_missing", r[:json].to_json[0, 120])

  r = call("bpmn.complete", {})
  check("job-id-required", r[:json]["reason"] == "job_id_required", r[:json].to_json[0, 120])

  # Run counts reach the ordinary read path, so the two halves agree about what
  # happened rather than each keeping its own story.
  r = call("bpmn.run.stat", { "definition_key" => "sdlc" })
  check("run-stat-sees-both-instances", result(r)["process_instances"] == 2,
        r[:json].to_json[0, 140])

  # Identity is still not minted here, on the write path either.
  r = call("bpmn.claim", { "spec_iri" => "urn:mm:bpmn:sdlc:1:HumanReview", "actor_id" => actor.id })
  check("write-path-refuses-an-iri-as-a-key",
        r[:json]["reason"] == "identity_not_minted_here", r[:json].to_json[0, 140])

  ok = CHECKS.all? { |c| c["ok"] }
  CHECKS.each { |c| puts format("  %s %s -- %s", c["ok"] ? "ok" : "FAIL", c["assertion"], c["detail"]) }
  puts "population: #{CHECKS.length} examined, 0 skipped"
  puts "sdlc seam: #{ok ? 'OK' : 'FAIL'}"
  exit(ok ? 0 : 1)
end

main
