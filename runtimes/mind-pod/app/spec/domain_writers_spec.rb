require "spec_helper"
require "fileutils"
require "json"

RSpec.describe DomainWriters do
  it "allows BACK any model and BACKJOB only Reconciliation" do
    expect(DomainWriters.allowed_class?("Note", "back")).to be(true)
    expect(DomainWriters.allowed_class?("Reconciliation", "backjob")).to be(true)
    expect(DomainWriters.allowed_class?("Note", "backjob")).to be(false)
    expect(DomainWriters.allowed_class?("Note", "front")).to be(false)
    expect(DomainWriters.allowed_table?("notes", "backjob")).to be(false)
    expect(DomainWriters.allowed_table?("reconciliations", "backjob")).to be(true)
  end

  it "refuses Note.create! when ROLE=backjob and records it" do
    previous = ENV["ROLE"]
    ENV["ROLE"] = "backjob"
    log = Rails.root.join("log", "cpcp_refusals-spec.jsonl")
    hb = Rails.root.join("log", "cpcp_refusal_observer-spec.json")
    ENV["CPCP_REFUSAL_LOG"] = log.to_s
    ENV["CPCP_REFUSAL_HEARTBEAT"] = hb.to_s
    FileUtils.mkdir_p(log.dirname)
    FileUtils.rm_f(log)
    expect { Note.create!(title: "no", body: "from backjob") }.to raise_error(DomainWriters::Refused)
    lines = File.readlines(log, chomp: true).map { |l| JSON.parse(l) }
    hit = lines.find { |r| r["reason"] == "domain_write_refused" }
    expect(hit).not_to be_nil
    expect(hit["because"]).to include("backjob")
  ensure
    ENV["ROLE"] = previous
    ENV.delete("CPCP_REFUSAL_LOG")
    ENV.delete("CPCP_REFUSAL_HEARTBEAT")
  end
end
