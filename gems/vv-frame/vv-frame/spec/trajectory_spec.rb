# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Frame::Trajectory do
  def stakeholder_slice
    Vv::Frame::Slice.new(key: "ship-the-board", aim: "A township can read its own record",
                         receiver: "Township supervisor", receiver_kind: "stakeholder",
                         outward_signal: { metric: "no re-contact", delay: "P7D" })
  end

  def developer_slice(for_slice: stakeholder_slice)
    Vv::Frame::Slice.new(key: "grounding-seam", aim: "The seam refuses an ungrounded publish",
                         receiver: "Substrate developer", receiver_kind: "developer",
                         outward_signal: { metric: "refusal observed", delay: "P1D" },
                         for_slice: for_slice)
  end

  def build(dir, slice: developer_slice, party: :development_agent, path: "grammar/x.ttl")
    b = Vv::Frame.load(dir).fetch(:bundle)
    described_class.for(bundle: b, path: path, slice: slice, party: party)
  end

  it "assembles aim, constraints and placement into one object" do
    BundleFixture.in_tmp do |dir|
      t = build(dir).fetch(:trajectory)
      expect(t.slice.aim).to include("refuses an ungrounded publish")
      expect(t.constraints.map(&:id)).to eq(["0001"])
      expect(t.gates).to eq(["tooling/boundary/check_closed.py"])
    end
  end

  it "orients transitively: agent to developer to stakeholder" do
    BundleFixture.in_tmp do |dir|
      t = build(dir).fetch(:trajectory)
      expect(t.chain).to eq(%w[grounding-seam ship-the-board])
      expect(t).to be_terminates_outside
    end
  end

  describe "T1 — the receiver predates the cut" do
    it "PLANT: a receiver the work created is refused by name" do
      slice = Vv::Frame::Slice.new(key: "s", aim: "go faster", receiver: "the coding agent",
                                   receiver_kind: "agent", outward_signal: { metric: "x" })
      f = slice.findings.find { |x| x[:test] == :receiver_did_not_predate_the_cut }
      expect(f).not_to be_nil
      expect(f[:suggested_resolution]).to eq("name a receiver who existed before this work did")
    end

    it "PLANT: an aim that never leaves the harness is a trajectory finding" do
      inner = Vv::Frame::Slice.new(key: "inner", aim: "green the suite", receiver: "the harness",
                                   receiver_kind: "harness", outward_signal: { metric: "x" })
      BundleFixture.in_tmp do |dir|
        t = build(dir, slice: inner).fetch(:trajectory)
        expect(t).not_to be_terminates_outside
        expect(t.findings.map { |x| x[:test] }).to include(:aim_ends_inside_the_system)
      end
    end

    it "names each forbidden receiver kind" do
      Vv::Frame::Slice::RECEIVER_FORBIDDEN.each do |kind|
        s = Vv::Frame::Slice.new(key: "s", aim: "a", receiver: "r", receiver_kind: kind,
                                 outward_signal: { metric: "x" })
        expect(s.findings.map { |f| f[:test] }).to include(:receiver_did_not_predate_the_cut)
      end
    end
  end

  describe "the outward signal" do
    it "distinguishes pending from failing from absent" do
      absent = Vv::Frame::Slice.new(key: "s", aim: "a", receiver: "r", receiver_kind: "developer")
      pending = Vv::Frame::Slice.new(key: "s", aim: "a", receiver: "r", receiver_kind: "developer",
                                     outward_signal: { metric: "m" })
      reporting = Vv::Frame::Slice.new(key: "s", aim: "a", receiver: "r", receiver_kind: "developer",
                                       outward_signal: { metric: "m", matured_at: "2026-09-19" })
      expect(absent.signal_state).to eq(:not_instrumented)
      expect(pending.signal_state).to eq(:pending)
      expect(reporting.signal_state).to eq(:reporting)
    end
  end

  describe "refusals" do
    it "refuses an unknown party" do
      BundleFixture.in_tmp do |dir|
        expect(build(dir, party: :marketing)).to include(ok: false, reason: :unknown_party)
      end
    end

    it "refuses a trajectory with no slice" do
      BundleFixture.in_tmp do |dir|
        b = Vv::Frame.load(dir).fetch(:bundle)
        res = described_class.for(bundle: b, path: "x", slice: nil)
        expect(res).to include(ok: false, reason: :slice_absent)
      end
    end

    it "PLANT: two slices receiving each other are one whole cut in half" do
      a = Vv::Frame::Slice.new(key: "a", aim: "a", receiver: "r", receiver_kind: "developer")
      b = Vv::Frame::Slice.new(key: "b", aim: "b", receiver: "r", receiver_kind: "developer",
                               for_slice: a)
      a.instance_variable_set(:@for_slice, b)
      BundleFixture.in_tmp do |dir|
        expect(build(dir, slice: a)).to include(ok: false, reason: :slices_are_one_whole)
      end
    end
  end

  describe "#to_markdown" do
    it "is loadable in one pass: receiver, aim, constraints, gates" do
      BundleFixture.in_tmp do |dir|
        md = build(dir).fetch(:trajectory).to_markdown
        expect(md).to include("**Receiver** — Substrate developer (developer)")
        expect(md).to include("grounding-seam → ship-the-board")
        expect(md).to include("## Constraints — decisions governing this path")
        expect(md).to include("## Gates — what will catch me")
        expect(md).to include("tooling/boundary/check_closed.py")
      end
    end
  end

  describe "the real bundle", if: Dir.exist?(BUNDLE_ROOT) do
    it "orients a development-time agent editing a governed path" do
      b = Vv::Frame.load(BUNDLE_ROOT).fetch(:bundle)
      res = described_class.for(bundle: b, slice: developer_slice,
                                path: "gems/rails-osi-level-8/lib/rails_osi_level_8")
      t = res.fetch(:trajectory)
      expect(t.constraints).not_to be_empty
      expect(t.to_markdown).to include("## Constraints")
    end

    it "gives a production-time agent the same object" do
      b = Vv::Frame.load(BUNDLE_ROOT).fetch(:bundle)
      path = "runtimes/mind-pod/app/bin/backjob"
      dev = described_class.for(bundle: b, path: path, slice: developer_slice,
                                party: :development_agent).fetch(:trajectory)
      prod = described_class.for(bundle: b, path: path, slice: developer_slice,
                                 party: :production_agent).fetch(:trajectory)
      expect(prod.constraints.map(&:id)).to eq(dev.constraints.map(&:id))
      expect(prod.gates).to eq(dev.gates)
    end
  end
end
