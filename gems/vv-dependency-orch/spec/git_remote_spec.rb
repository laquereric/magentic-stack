# frozen_string_literal: true

# SHALLOWNESS UNDERMINES ABSENCE, NOT PRESENCE.
#
# The adapter's first version refused to look at all in a shallow checkout, on
# the reasoning that a shallow clone cannot decide reachability. Half right, and
# the wrong half was load-bearing: `cat-file -e` succeeding means the object is
# RIGHT THERE, and no amount of truncated history makes that less true.
#
# Pointed at magentic-stack it cost every pinned revision. Five of the six
# submodules are shallow, most of them have the exact commit being asked about
# checked out, and all thirteen came back unreachable -- so drift reported "no
# placement gave a completed answer" for the entire git half and read as
# coverage rather than as the gap it was.
#
# The rule that survives: a source that cannot prove a negative can still prove
# a positive. The shallow test belongs on the FAILURE branch only.
RSpec.describe Vv::DependencyOrch::Adapters::GitRemote do
  # `shallow?` and `cat-file` are two calls to the same scripted runner, so
  # these fakes drive them by argv rather than by call order -- order-dependent
  # fakes pass for the wrong reason the moment an implementation adds a call.
  class GitScript < Vv::DependencyOrch::Adapters::GitRemote
    def initialize(shallow:, has_commit:)
      super()
      @shallow = shallow
      @has_commit = has_commit
    end

    def available? = true

    def run(argv, timeout: nil)
      if argv.include?("--is-shallow-repository")
        [:ok, @shallow ? "true\n" : "false\n", ""]
      elsif argv.include?("cat-file")
        @has_commit ? [:ok, "", ""] : [:failed, "", "fatal: Not a valid object name"]
      else
        [:ok, "", ""]
      end
    end
  end

  let(:rev) { "8b3c719144748e7242645ef65eb4034c9ea727f4" }

  context "a SHALLOW checkout that HAS the commit" do
    subject(:placement) do
      GitScript.new(shallow: true, has_commit: true).placement_for(rev, root: "/x/nooa/src")
    end

    it "is present: the object is there and depth cannot argue with that" do
      expect(placement.state).to eq(:present)
    end

    it "records that the checkout was depth-limited anyway" do
      expect(placement.details[:shallow]).to be(true)
    end
  end

  context "a SHALLOW checkout that does NOT have the commit" do
    subject(:placement) do
      GitScript.new(shallow: true, has_commit: false).placement_for(rev, root: "/x/nooa/src")
    end

    # This is the rollback_target case in magentic-stack: nooa pins one, and the
    # shallow clone does not carry it. "Not here" from truncated history is not
    # evidence, and calling it absent would send someone to re-pin a commit that
    # never moved.
    it "is unreachable, never absent" do
      expect(placement.state).to eq(:unreachable)
    end

    it "says what to do about it" do
      expect(placement.because).to include("establishes nothing")
      expect(placement.because).to include("unshallow")
    end
  end

  context "a FULL checkout that does not have the commit" do
    subject(:placement) do
      GitScript.new(shallow: false, has_commit: false).placement_for(rev, root: "/x/full")
    end

    # The mirror, so the fix is not read as "never say absent about git". A full
    # checkout completing the lookup IS entitled to answer.
    it "is absent, because a full checkout is entitled to say so" do
      expect(placement.state).to eq(:absent)
    end
  end

  describe "#placement_across" do
    # The superproject almost never holds the pin; the submodule does. Searching
    # only the roots is why these resources had no placement at all.
    it "finds the revision in a submodule checkout, not the superproject" do
      # The path is a FAKE and deliberately does not say "upstreams/".
      # check_boundary reserves that prefix to gems/adapters/ and reads source
      # without knowing which strings are fixtures -- correctly, since a rule
      # that trusted "it is only a test" would be a rule with a hole in it. The
      # assertion is about which checkout answers, not about the name.
      adapter = GitScript.new(shallow: true, has_commit: true)
      allow(adapter).to receive(:checkouts).and_return(["/x/deps/nooa/src"])

      expect(adapter.placement_across(rev, roots: ["/x"]).state).to eq(:present)
    end

    it "refuses to conclude absence when any checkout that could not answer was shallow" do
      adapter = GitScript.new(shallow: true, has_commit: false)
      allow(adapter).to receive(:checkouts).and_return(["/x", "/x/deps/nooa/src"])

      placement = adapter.placement_across(rev, roots: ["/x"])
      expect(placement.state).to eq(:unreachable)
      expect(placement.because).to include("shallow")
    end

    it "concludes absence only when every checkout was full and completed" do
      adapter = GitScript.new(shallow: false, has_commit: false)
      allow(adapter).to receive(:checkouts).and_return(["/x", "/x/sub"])

      expect(adapter.placement_across(rev, roots: ["/x"]).state).to eq(:absent)
    end
  end
end
