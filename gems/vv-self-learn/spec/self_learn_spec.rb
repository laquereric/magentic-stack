# frozen_string_literal: true

RSpec.describe Vv::SelfLearn do
  def sha(ch = "b")
    "sha256:" + (ch * 64)
  end

  describe "operations" do
    it "is exactly three v1 methods" do
      expect(Vv::SelfLearn::Operations.names)
        .to eq(%w[learn.collect learn.eval learn.recommend])
    end

    it "refuses Ornith envelopes as not v1" do
      r = Vv::SelfLearn::Loop.dispatch("ornith.grpo", {})
      expect(r[:reason]).to eq("ornith_not_v1")
      r2 = Vv::SelfLearn::Loop.dispatch("learn.task.put", {})
      expect(r2[:reason]).to eq("ornith_not_v1")
    end
  end

  describe "Wilson" do
    it "gives a wide interval for 5/5, not perfect reliability" do
      r = Vv::SelfLearn::Wilson.interval(5, 5)
      expect(r[:ok]).to be(true)
      expect(r[:rate]).to eq(1.0)
      lo, hi = r[:wilson95]
      expect(lo).to be_within(0.02).of(0.57)
      expect(hi).to eq(1.0)
    end

    it "refuses n=0" do
      expect(Vv::SelfLearn::Wilson.interval(0, 0)[:reason]).to eq("n_not_planned")
    end
  end

  describe "collect" do
    it "lands observed Bronze citing Gold" do
      r = Vv::SelfLearn::Loop.collect("gold_digest" => sha)
      expect(r[:ok]).to be(true)
      expect(r[:provenance]).to eq("observed")
      expect(r[:generation]).to eq(0)
    end

    it "refuses a summary stamped as collect" do
      r = Vv::SelfLearn::Loop.collect("gold_digest" => sha, "summary" => "it went well")
      expect(r[:reason]).to eq("bronze_mutated")
    end
  end

  describe "eval / recommend" do
    it "refuses an LLM judge on a digest task" do
      r = Vv::SelfLearn::Loop.eval("n" => 1, "passes" => 1, "grader" => "llm")
      expect(r[:reason]).to eq("grader_not_deterministic")
    end

    it "recommends a deterministic full pass" do
      r = Vv::SelfLearn::Loop.eval(
        "n" => 4, "passes" => 4, "deterministic" => true,
        "gold_digest" => sha("a"), "candidate_digest" => sha("a")
      )
      expect(r[:ok]).to be(true)
      expect(r[:recommend]).to be(true)
      expect(r[:n]).to eq(4)
    end

    it "does not treat equal scores of two Golds as better" do
      r = Vv::SelfLearn::Loop.eval(
        "n" => 4, "passes" => 4, "deterministic" => true,
        "gold_digest" => sha("a"), "candidate_digest" => sha("c"),
        "gold_rate" => 1.0
      )
      expect(r[:delta_rate]).to eq(0.0)
      expect(r[:recommend]).to be(false)
      expect(r[:because]).to include("not evidence")
    end

    it "refuses eval from PROD role" do
      r = Vv::SelfLearn::Loop.dispatch("learn.eval", "role" => "prod", "n" => 1, "passes" => 1)
      expect(r[:reason]).to eq("prod_write_refused")
    end

    it "allows collect from PROD role" do
      r = Vv::SelfLearn::Loop.dispatch("learn.collect", "role" => "prod", "gold_digest" => sha)
      expect(r[:ok]).to be(true)
    end
  end

  describe "CPCP" do
    it "refuses to register without rails-cpcp" do
      r = Vv::SelfLearn::Cpcp.register!
      expect(r[:ok]).to be(false)
    end
  end

  describe "absence" do
    it "does not contain GRPO, ActiveRecord, or DuckDB" do
      blob = Dir[File.expand_path("../lib/**/*.rb", __dir__)].map { |p| File.read(p) }.join
      expect(blob).not_to match(/ActiveRecord::Base/)
      expect(blob).not_to match(/require ["']duckdb["']/)
      expect(blob).not_to match(/def train!/)
    end
  end
end
