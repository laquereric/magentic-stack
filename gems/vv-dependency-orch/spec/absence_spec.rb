# frozen_string_literal: true

# GATE: `unreachable` is not `absent`.
#
# The plan states it plainly -- "silence from a VPS is not evidence its image is
# gone" -- and this is the gate that makes it true of the code rather than of
# the prose. The structural claim under test is that on a timeout the
# interpreting block NEVER RUNS, so it cannot mis-decide.
RSpec.describe "absence" do
  let(:digest) { "sha256:#{'c' * 64}" }

  describe Vv::DependencyOrch::Placement do
    it "keeps four states and marks only two as evidence" do
      expect(described_class::STATES).to contain_exactly(:present, :absent, :unreachable, :not_indexed)
      expect(described_class::COMPLETED).to contain_exactly(:present, :absent)
    end

    it "does not treat unreachable as evidence" do
      placement = described_class.unreachable(kind: :host, at: "sharedai.space", because: "timeout")
      expect(placement.evidence?).to be false
      expect(placement.present?).to be false
    end

    # PLANT: an adapter that runs after a failed one must not downgrade a
    # completed observation back to "nobody looked".
    it "refuses to supersede a completed observation with not_indexed" do
      completed = described_class.present(kind: :local_daemon, at: "local")
      nothing = described_class.never_looked(kind: :local_daemon, at: "local")
      expect(nothing.supersedes?(completed)).to be false
      expect(completed.supersedes?(nothing)).to be true
    end

    it "lets evidence supersede a non-answer" do
      unreachable = described_class.unreachable(kind: :registry, at: "ghcr.io", because: "401")
      absent = described_class.absent(kind: :registry, at: "ghcr.io", because: "registry said no")
      expect(absent.supersedes?(unreachable)).to be true
      expect(unreachable.supersedes?(absent)).to be false
    end
  end

  describe Vv::DependencyOrch::Adapters::Base do
    # PLANT: a host that times out must not report the image missing.
    it "returns unreachable on a timeout without ever calling the interpreting block" do
      adapter = FakeAdapters::Scripted.new(outcome: :timeout)
      ran = false

      placement = adapter.probe do
        ran = true
        [:absent, "the block decided it was gone"]
      end

      expect(ran).to be(false), "the block ran on a timeout; it must not be able to decide absence"
      expect(placement.state).to eq(:unreachable)
      expect(placement.evidence?).to be false
      expect(placement.because).to match(/silence is not absence/)
    end

    it "returns unreachable when the tool is missing, not absent" do
      adapter = FakeAdapters::Scripted.new(outcome: :missing, stderr: "docker is not on PATH")
      placement = adapter.probe { |_s, _o, _e| [:absent, "nope"] }
      expect(placement.state).to eq(:unreachable)
    end

    it "asks nothing at all when the adapter is unavailable" do
      adapter = FakeAdapters::Scripted.new(outcome: :ok, available: false)
      placement = adapter.probe { |_s, _o, _e| [:present, {}] }
      expect(placement.state).to eq(:unreachable)
      expect(adapter.calls).to be_empty
    end

    it "lets a completed round trip say absent" do
      adapter = FakeAdapters::Scripted.new(outcome: :failed, stderr: "No such image: x")
      placement = adapter.probe { |_s, _o, _e| [:absent, "the daemon answered and holds no such image"] }
      expect(placement.state).to eq(:absent)
      expect(placement.evidence?).to be true
    end

    # An unrecognised verdict is precisely the case where we do not know, and
    # the safe direction is always away from `absent`.
    it "falls back to unreachable on an unrecognised verdict" do
      adapter = FakeAdapters::Scripted.new(outcome: :ok)
      placement = adapter.probe { |_s, _o, _e| [:probably_fine, "shrug"] }
      expect(placement.state).to eq(:unreachable)
    end
  end

  describe Vv::DependencyOrch::Adapters::GitRemote do
    # PLANT: a shallow checkout that would answer "orphaned" must be refused.
    it "refuses ancestry from a shallow clone instead of answering from local reachability" do
      adapter = described_class.new
      allow(adapter).to receive(:shallow?).and_return(true)
      allow(adapter).to receive(:available?).and_return(true)

      placement = adapter.placement_for("d" * 40, root: "/tmp/shallow")
      expect(placement.state).to eq(:unreachable)
      expect(placement.because).to match(/shallow/)

      result = adapter.contains?("d" * 40, root: "/tmp/shallow")
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("not_indexed")
      expect(result[:because]).to match(/would report orphaned for a commit that is not/)
    end
  end
end
