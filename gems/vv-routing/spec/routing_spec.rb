# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Routing do
  R = Vv::Routing::Route

  # THE POINT OF THE GEM. Same task, same tier, different plane, different rule.
  describe "the plane decides what the cheap tier costs you" do
    it "routes mechanical synthesis work to the router tier without ceremony" do
      route = R.new(task: "extract the migration's table name", kind: :extraction,
                    plane: :synthesis, tier: :router)
      expect(route.plane).to be_synthesis
      expect(route.verified?).to be false
      # Nothing was named, and nothing needed to be: the toolchain reads it.
      expect(route.plane.verified_by).to match(/specs, sweep gates, review/)
    end

    it "refuses the same shape on the production plane" do
      expect {
        R.new(task: "extract the caller's slug", kind: :extraction,
              plane: :production, tier: :router)
      }.to raise_error(R::Unverified, /nothing does, unless you\s+say what/)
    end

    it "allows it once a verifier is named" do
      route = R.new(task: "extract the caller's slug", kind: :extraction,
                    plane: :production, tier: :router,
                    verifier: "TB::AciaLatestPullShape twin")
      expect(route.verified?).to be true
    end

    it "allows the frontier tier on production without a named verifier" do
      route = R.new(task: "write the reply the reader sees", kind: :prose,
                    plane: :production, tier: :frontier)
      expect(route.verified?).to be false
    end

    # An omission nobody notices becomes a recorded decision someone can argue
    # with.
    it "allows an explicitly accepted unverified route, with a reason" do
      route = R.new(task: "classify a log line", kind: :classification,
                    plane: :production, tier: :router,
                    verifier: R::ACCEPTED_UNVERIFIED,
                    because: "worst case is a mislabelled log line; nothing reads it")
      expect(route.unverified_accepted?).to be true
      expect(route.because).to match(/mislabelled log line/)
    end
  end

  describe "tiers report suitability rather than enforcing it" do
    it "knows what the article says each tier is for" do
      expect(Vv::Routing::Tier.router.suits?(:tool_call)).to be true
      expect(Vv::Routing::Tier.router.suits?(:prose)).to be false
      expect(Vv::Routing::Tier.frontier.suits?(:prose)).to be true
    end

    # Routing prose to the small tier is a choice someone may make with reason.
    # This gem reports the mismatch; it does not forbid it.
    it "reports a mismatch without refusing the route" do
      route = R.new(task: "summarise for a human", kind: :prose,
                    plane: :synthesis, tier: :router)
      expect(route.tier_suits_kind?).to be false
    end

    it "names no models, because SWITCH owns that" do
      source = File.read(File.expand_path("../lib/vv/routing/tier.rb", __dir__))
      code = source.lines.reject { |l| l.strip.start_with?("#") }.join
      expect(code).not_to match(/DeepSeek|Qwen|GPT-4|Claude/i)
    end
  end

  # A cliff, not a slope: 99% identical is a miss.
  describe "prefix discipline" do
    P = Vv::Routing::Prefix

    it "calls an identical prefix stable" do
      p1 = "SYSTEM: you extract fields.\nTOOLS: [...]"
      expect(P.audit(p1, p1.dup)[:stable]).to be true
      expect(P.audit(p1, p1.dup)[:verdict]).to match(/cacheable/)
    end

    it "calls a changed prefix a miss, not a smaller discount" do
      a = P.audit("SYSTEM: you extract fields.", "SYSTEM: You extract fields.")
      expect(a[:stable]).to be false
      expect(a[:verdict]).to match(/a partial match is a miss/)
    end

    it "spots a timestamp that will void every hit after the first" do
      prefix = "SYSTEM: 2026-09-06 09:15 — you extract fields."
      expect(P.cacheable?(prefix)).to be false
      expect(P.volatile_parts(prefix)).to include("a timestamp")
    end

    it "spots a uuid and a request id" do
      expect(P.volatile_parts("run 3f2504e0-4f89-11d3-9a0c-0305e82c3301"))
        .to include("a uuid")
      expect(P.volatile_parts("request_id: abc")).to include("a request id")
    end

    # Identical today, doomed tomorrow -- worth saying before the bill does.
    it "warns when a prefix is identical this turn but carries something volatile" do
      p = "SYSTEM: request_id stays out of the prefix, usually"
      expect(P.audit(p, p.dup)[:verdict]).to match(/it will move/)
    end

    it "accepts a clean prefix" do
      expect(P.cacheable?("SYSTEM: you extract fields.\nTOOLS: [...]")).to be true
    end
  end

  describe "planes" do
    it "refuses a plane that is not one of the two" do
      expect { Vv::Routing::Plane.new(:staging) }
        .to raise_error(Vv::Routing::Plane::UnknownPlane, /not a plane/)
    end

    it "says the synthesis verifier is structural and the production one is not" do
      expect(Vv::Routing::Plane.synthesis.verifier_implicit?).to be true
      expect(Vv::Routing::Plane.production.verifier_implicit?).to be false
      expect(Vv::Routing::Plane.production.verified_by).to match(/nothing, unless/)
    end
  end
end
