# frozen_string_literal: true

RSpec.describe Vv::Orinth do
  def sha(ch = "d")
    "sha256:" + (ch * 64)
  end

  describe "v1 blocker" do
    it "refuses to arm without plants" do
      r = Vv::Orinth::V1Binding.bind!
      expect(r[:reason]).to eq("ornith_v1_required")
      expect(r[:because]).to include("learn.collect")
    end

    it "still refuses when every plant name is passed, because weights are not in the pod" do
      r = Vv::Orinth::V1Binding.bind!(plants: Vv::Orinth::V1Binding::WAITING)
      expect(r[:ok]).to be(false)
      expect(r[:because]).to include("no engine change has landed")
    end
  end

  describe "five envelopes" do
    it "lands an observed task" do
      r = Vv::Orinth::Envelopes.put("task", "kind" => "shape.render.ghis-19")
      expect(r[:ok]).to be(true)
      expect(r[:provenance]).to eq("observed")
      expect(r[:generation]).to eq(0)
    end

    it "requires cites on scaffold/rollout/reward" do
      expect(Vv::Orinth::Envelopes.put("scaffold", {})[:reason]).to eq("blob_digest_required")
      r = Vv::Orinth::Envelopes.put("scaffold", "task_digest" => sha)
      expect(r[:ok]).to be(true)
    end

    it "forces monitor hits to score 0" do
      r = Vv::Orinth::Envelopes.put("monitor", "rollout_digest" => sha, "fired" => true)
      expect(r[:fired]).to be(true)
      expect(r[:rollout_score]).to eq(0)
    end

    it "refuses PROD puts" do
      r = Vv::Orinth::Envelopes.put("task", "role" => "prod")
      expect(r[:reason]).to eq("prod_write_refused")
    end

    it "refuses verifier edits" do
      r = Vv::Orinth::Envelopes.put("scaffold", "task_digest" => sha, "edit_verifier" => true)
      expect(r[:reason]).to eq("verifier_edit_refused")
    end

    it "cycle.put needs all five" do
      expect(Vv::Orinth::Envelopes.cycle({})[:reason]).to eq("cycle_incomplete")
      r = Vv::Orinth::Envelopes.cycle(
        "task" => {},
        "scaffold" => { "task_digest" => sha },
        "rollout" => { "task_digest" => sha, "scaffold_digest" => sha },
        "reward" => { "rollout_digest" => sha, "validity" => 1 },
        "monitor" => { "rollout_digest" => sha }
      )
      expect(r[:ok]).to be(true)
      expect(r[:kinds]).to eq(Vv::Orinth::Envelopes::KINDS)
    end
  end

  describe "GRPO" do
    it "does not promote Gold" do
      r = Vv::Orinth::Grpo.step(
        "task_digest" => sha, "scaffold_digest" => sha,
        "rollout_digest" => sha, "reward_digest" => sha, "promote" => true
      )
      expect(r[:reason]).to eq("platinum_not_a_tier")
    end

    it "skips advantage on monitor fire" do
      r = Vv::Orinth::Grpo.step(
        "task_digest" => sha, "scaffold_digest" => sha,
        "rollout_digest" => sha, "reward_digest" => sha, "monitor_fired" => true
      )
      expect(r[:ok]).to be(true)
      expect(r[:advantage]).to eq(0)
    end

    it "declares a MIND checkpoint, and does not train" do
      r = Vv::Orinth::Grpo.step(
        "task_digest" => sha, "scaffold_digest" => sha,
        "rollout_digest" => sha, "reward_digest" => sha
      )
      expect(r[:ok]).to be(true)
      expect(r[:policy_kind]).to eq("mind_checkpoint")
      expect(r[:because]).to include("does not train")
    end
  end

  describe "operations" do
    it "names the seven v2 methods" do
      expect(Vv::Orinth::Operations.names).to include(
        "ornith.task.put", "ornith.cycle.put", "ornith.grpo"
      )
      expect(Vv::Orinth::Operations.names.size).to eq(7)
    end
  end

  describe "CPCP" do
    it "refuses to register without rails-cpcp" do
      r = Vv::Orinth::Cpcp.register!
      expect(r[:ok]).to be(false)
    end
  end

  describe "absence" do
    it "does not grow ActiveRecord, DuckDB, or a trainer" do
      blob = Dir[File.expand_path("../lib/**/*.rb", __dir__)].map { |p| File.read(p) }.join
      expect(blob).not_to match(/ActiveRecord::Base/)
      expect(blob).not_to match(/require ["']duckdb["']/)
      expect(blob).not_to match(/def train!/)
    end
  end
end
