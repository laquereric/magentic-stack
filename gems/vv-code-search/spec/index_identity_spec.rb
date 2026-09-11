# frozen_string_literal: true

RSpec.describe Vv::CodeSearch::Index do
  let(:corpus) { { "Gemfile.lock" => "GEM\n  specs:\n    rake (13.0.6)\n" } }

  describe "content addressing" do
    it "keys on the identity tuple, so the same tree at two revs is two indices" do
      with_corpus(corpus) do |root|
        with_store do |store|
          a = described_class.build(repo: "demo", rev: "rev1", schema: "magentic-pins", root: root, store: store)
          b = described_class.build(repo: "demo", rev: "rev2", schema: "magentic-pins", root: root, store: store)

          expect(a[:digest]).not_to eq(b[:digest])
        end
      end
    end

    it "gives two SCHEMAS over the same rev two digests, so they cannot merge" do
      # plan_vv-code-search gate: "Two schemas for the same (repo, rev) must not
      # silently merge." Identity includes schema_id precisely so that the merge
      # has nowhere to happen -- it is prevented by addressing, not by a check
      # that someone has to remember to run.
      with_corpus(corpus) do |root|
        with_store do |store|
          pins = described_class.build(repo: "demo", rev: "rev1", schema: "magentic-pins", root: root, store: store)
          full = described_class.build(repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store)

          expect(pins[:digest]).not_to eq(full[:digest])

          # And each opens as what it was built as, not as the other.
          expect(described_class.open(digest: pins[:digest], store: store)[:index].schema.names).to eq([:pins])
          expect(described_class.open(digest: full[:digest], store: store)[:index].schema.names).to eq(%i[pins lexical])
        end
      end
    end

    it "separates forks of the same rev" do
      with_corpus(corpus) do |root|
        with_store do |store|
          upstream = described_class.build(repo: "demo", fork: "origin", rev: "r", schema: "magentic-pins", root: root, store: store)
          forked = described_class.build(repo: "demo", fork: "acme", rev: "r", schema: "magentic-pins", root: root, store: store)

          expect(upstream[:digest]).not_to eq(forked[:digest])
        end
      end
    end

    it "refuses to write over an index whose manifest names a different identity" do
      # The digest is supposed to imply the tuple. Trusting that rather than
      # re-reading it is what would make a collision invisible, so build compares
      # instead of assuming.
      with_corpus(corpus) do |root|
        with_store do |store|
          built = described_class.build(repo: "demo", rev: "r", schema: "magentic-pins", root: root, store: store)
          manifest = File.join(store, built[:digest], "manifest.json")
          tampered = JSON.parse(File.read(manifest)).merge("rev" => "someone-elses-rev")
          File.write(manifest, JSON.generate(tampered))

          again = described_class.build(repo: "demo", rev: "r", schema: "magentic-pins", root: root, store: store)
          expect(again[:ok]).to be(false)
          expect(again[:reason]).to eq("schema_collision")
        end
      end
    end
  end

  describe "refusals" do
    it "refuses an unregistered schema by name" do
      with_corpus(corpus) do |root|
        with_store do |store|
          result = described_class.build(repo: "demo", rev: "r", schema: "no-such-family", root: root, store: store)
          expect(result[:reason]).to eq("schema_unknown")
        end
      end
    end

    it "refuses to open a digest the store does not hold" do
      with_store do |store|
        result = described_class.open(digest: "0" * 64, store: store)
        expect(result[:reason]).to eq("index_unreadable")
      end
    end

    it "refuses a corrupt index rather than reporting it as a miss" do
      # A half-read index that answers "no hits" is the worst outcome available:
      # it looks exactly like evidence.
      with_corpus(corpus) do |root|
        with_store do |store|
          built = described_class.build(repo: "demo", rev: "r", schema: "magentic-pins", root: root, store: store)
          File.write(File.join(store, built[:digest], "pins.json"), "{not json")

          result = described_class.open(digest: built[:digest], store: store)
          expect(result[:ok]).to be(false)
          expect(result[:reason]).to eq("index_corrupt")
        end
      end
    end
  end

  describe "the hot union" do
    it "refuses to register a schema holding a scan-shaped dimension" do
      # plan_vv-code-search: "If a dimension cannot answer by line in < 1 s, it
      # is not in the hot union; it stays batch." Enforced at registration,
      # because measuring it per request is already too late.
      scanner = Class.new(Vv::CodeSearch::Dimension) do
        def self.name = :slow_scan
        def self.point_query? = false
        def self.build(root:) = Vv::CodeSearch::Built.new(postings: {}, coverage: nil)
      end

      expect do
        Vv::CodeSearch::Schema.register(id: "planted", dimensions: [scanner], why: "plant")
      end.to raise_error(ArgumentError, /stays batch/)
    ensure
      Vv::CodeSearch::Schema::REGISTRY.delete("planted")
    end
  end
end
