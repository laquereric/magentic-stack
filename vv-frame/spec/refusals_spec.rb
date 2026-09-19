# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the refusals" do
  # R1 and R2 are enforced by the absence of a method, not by a validation.
  # These specs are the gate on that absence: add a summariser or a ranker and
  # they fail. The thing you may not do is the thing you have no way to do.

  CLASSES = [Vv::Frame, Vv::Frame::Bundle, Vv::Frame::Concept,
             Vv::Frame::Decision, Vv::Frame::Section, Vv::Frame::Placement].freeze

  it "R1/R2: no object in the gem answers to a summarising or ranking name" do
    offenders = CLASSES.flat_map do |k|
      names = k.instance_methods(false) + k.methods(false)
      names.select { |m| Vv::Frame::REFUSED_OPERATIONS.any? { |r| m.to_s.include?(r.to_s) } }
           .map { |m| "#{k}##{m}" }
    end
    expect(offenders).to be_empty
  end

  it "R1: the gem's source carries no summarisation or scoring method" do
    src = Dir[File.expand_path("../lib/**/*.rb", __dir__)].map { |f| File.read(f) }.join("\n")
    defs = src.scan(/^\s*def\s+(?:self\.)?(\w+)/).flatten
    bad = defs.select { |d| Vv::Frame::REFUSED_OPERATIONS.any? { |r| d.include?(r.to_s) } }
    expect(bad).to be_empty
  end

  it "R2: no placement or decision carries a priority, rank or score field" do
    BundleFixture.in_tmp do |dir|
      d = Vv::Frame.load(dir).fetch(:bundle).decisions.first
      %w[priority rank score position weight].each do |field|
        expect(d.frontmatter).not_to have_key(field)
      end
      expect(d.placement.to_h.keys).to eq(%i[layer phase rung evidence instrument])
    end
  end

  it "R2: ordering is by structure, so the same question twice gives the same answer" do
    BundleFixture.in_tmp do |dir|
      b = Vv::Frame.load(dir).fetch(:bundle)
      5.times { expect(b.for_path("grammar/x.ttl").map(&:id)).to eq(["0001"]) }
    end
  end

  it "names a token count as an estimate rather than a measurement" do
    BundleFixture.in_tmp do |dir|
      d = Vv::Frame.load(dir).fetch(:bundle).decisions.first
      expect(d).to respond_to(:estimated_tokens)
      expect(d).not_to respond_to(:tokens)
      expect(d.chars).to be > 0
      expect(d.estimated_tokens).to eq((d.chars / 4.0).ceil)
    end
  end
end
