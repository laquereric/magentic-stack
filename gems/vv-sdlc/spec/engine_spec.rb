# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Sdlc::Engine do
  def complete_services_until_review
    started = described_class.start("definition_key" => "sdlc")
    id = started[:process_instance_id]
    loop do
      jobs = started[:jobs]
      break if jobs.empty? || jobs[0]["element_id"] == "HumanReview"

      started = described_class.complete("job_id" => jobs[0]["id"], "outcome" => "done")
    end
    [id, started]
  end

  it "seeds the sdlc package once" do
    a = Vv::Sdlc.seed
    b = Vv::Sdlc.seed
    expect(a[:ok]).to eq(true)
    expect(b[:already]).to eq(true)
    expect(Vv::BpmnBbo::Package.find_by(definition_key: "sdlc")).not_to be_nil
    proc = Vv::BpmnBbo::Process.joins(:definition_version)
                               .find_by(element_id: "AgentTask")
    ids = proc.flow_nodes.pluck(:element_id)
    expect(ids).to include("AgentDraft", "AgentTests", "RealityTest", "HumanReview", "ObsCheck")
  end

  it "starts on sdlc and lands on AgentDraft, not HumanReview" do
    out = described_class.start("definition_key" => "sdlc")
    expect(out[:ok]).to eq(true)
    expect(out[:jobs][0]["element_id"]).to eq("AgentDraft")
    expect(out[:jobs][0]["kind"]).to eq("service")
  end

  it "refuses to start a non-sdlc definition" do
    out = described_class.start("definition_key" => "orders")
    expect(out[:ok]).to eq(false)
    expect(out[:reason]).to eq(:not_sdlc)
  end

  it "does not treat AgentTests as the ship gate" do
    started = described_class.start("definition_key" => "sdlc")
    %w[AgentDraft AgentTests].each do |want|
      job = started[:jobs][0]
      expect(job["element_id"]).to eq(want)
      started = described_class.complete("job_id" => job["id"])
    end
    expect(started[:state]).to eq("running")
    expect(started[:jobs][0]["element_id"]).to eq("RealityTest")
  end

  it "requires an Actor claim before HumanReview completes" do
    _id, at_review = complete_services_until_review
    job = at_review[:jobs][0]
    expect(job["element_id"]).to eq("HumanReview")
    expect(job["kind"]).to eq("user")

    skip = described_class.complete("job_id" => job["id"], "outcome" => "accept")
    expect(skip[:ok]).to eq(false)
    expect(skip[:reason]).to eq(:job_not_claimed)

    actor = Vv::Base::Actor.create!(name: "Priya", role_key: "reviewer")
    claimed = described_class.claim("job_id" => job["id"], "actor_id" => actor.id)
    expect(claimed[:ok]).to eq(true)

    done = described_class.complete("job_id" => job["id"], "outcome" => "accept")
    expect(done[:ok]).to eq(true)
    expect(done[:jobs][0]["element_id"]).to eq("ObsCheck")
  end

  it "cannot skip HumanReview: there is no job for End_ok until review accepts" do
    id, at_review = complete_services_until_review
    jobs = Vv::BpmnBbo::Run::Job.where(process_instance_id: id)
    expect(jobs.map { |j| j.flow_node.element_id }).not_to include("ObsCheck")
    expect(at_review[:state]).to eq("running")
    inst = Vv::BpmnBbo::Run::ProcessInstance.find(id)
    expect(inst.state).not_to eq("completed")
  end

  it "reject at review terminates without ObsCheck" do
    _id, at_review = complete_services_until_review
    job = at_review[:jobs][0]
    actor = Vv::Base::Actor.create!(name: "Sam", role_key: "r2")
    described_class.claim("job_id" => job["id"], "actor_id" => actor.id)
    out = described_class.complete("job_id" => job["id"], "outcome" => "reject")
    expect(out[:state]).to eq("terminated")
    expect(out[:jobs]).to eq([])
  end

  it "handles? only sdlc" do
    expect(described_class.handles?("definition_key" => "sdlc")).to eq(true)
    expect(described_class.handles?("definition_key" => "orders")).to eq(false)
  end
end
