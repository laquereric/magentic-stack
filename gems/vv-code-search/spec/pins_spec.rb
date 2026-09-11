# frozen_string_literal: true

RSpec.describe Vv::CodeSearch::Dimensions::Pins do
  describe "declares vs references" do
    it "reads a lockfile spec line as a DECLARATION and its transitive requirement as a REFERENCE" do
      with_corpus(
        "Gemfile.lock" => <<~LOCK
          GEM
            remote: https://rubygems.org/
            specs:
              rake (13.0.6)
              rspec (3.13.0)
                rspec-core (~> 3.13.0)

          DEPENDENCIES
            rspec (~> 3.13)
        LOCK
      ) do |root|
        built = described_class.build(root: root)
        lines = built.postings.fetch("Gemfile.lock")

        # `    rake (13.0.6)` decides a version.
        expect(lines[4].first).to include("kind" => "declares", "name" => "rake", "version" => "13.0.6")

        # `      rspec-core (~> 3.13.0)` is rspec's requirement, not this tree's decision.
        expect(lines[6].first).to include("kind" => "references", "name" => "rspec-core")

        # DEPENDENCIES names what this tree asked for.
        expect(lines[9].first).to include("kind" => "references", "name" => "rspec")
      end
    end

    it "reads a pin manifest's pinned_revision as a declaration and its rollback target as a reference" do
      with_corpus(
        "upstreams/manifests/nooa.pin.json" => <<~JSON
          {
            "name": "nooa",
            "pinned_revision": "8b3c719144748e7242645ef65eb4034c9ea727f4",
            "rollback_target": "25c1afa51568d7bbb20212e020050d584bc7f7c5"
          }
        JSON
      ) do |root|
        lines = described_class.build(root: root).postings.fetch("upstreams/manifests/nooa.pin.json")

        expect(lines[3].first).to include(
          "kind" => "declares", "ecosystem" => "git", "name" => "nooa",
          "version" => "8b3c719144748e7242645ef65eb4034c9ea727f4"
        )
        # A rollback target that moves is a different problem from a pin that
        # moves. Merging them would hide both.
        expect(lines[4].first).to include("kind" => "references")
      end
    end

    it "reads a digest-pinned image as a declaration" do
      with_corpus(
        "compose.yml" => <<~YAML
          services:
            milvus:
              image: milvusdb/milvus@sha256:38a6ba6378c602bfb187f4f34077f384c160edf1cf329aa22d99fb58b81b2497
        YAML
      ) do |root|
        entry = described_class.build(root: root).postings.fetch("compose.yml")[3].first
        expect(entry).to include("kind" => "declares", "ecosystem" => "oci", "name" => "milvusdb/milvus")
        expect(entry["version"]).to start_with("sha256:")
      end
    end

    it "does not claim a submodule revision it cannot see" do
      # The gitlink SHA lives in the tree object, not in .gitmodules. Saying
      # "declares" here would be a lie a reverse-index consumer would act on.
      # The path is deliberately meaningless to this repo. Two boundary rules
      # read source without knowing which strings are fixtures -- correctly,
      # since a rule that trusted "it is only a test" would be a rule with a
      # hole in it. `upstreams/` is reserved to gems/adapters/ (check_boundary)
      # and `vendor/` no longer exists here, so naming either would be a dead
      # or misrouted reference. The assertion is about `kind`, which does not
      # depend on the path being one this repo has.
      with_corpus(
        ".gitmodules" => <<~MOD
          [submodule "example/src"]
          \tpath = example/src
          \turl = https://example.invalid/example
        MOD
      ) do |root|
        entries = described_class.build(root: root).postings.fetch(".gitmodules").values.flatten
        expect(entries.map { |e| e["kind"] }.uniq).to eq(["references"])
      end
    end
  end

  describe "coverage" do
    it "reports nil coverage, because it walks the whole tree and selects pin sources from it" do
      with_corpus("Gemfile.lock" => "GEM\n  specs:\n    rake (13.0.6)\n") do |root|
        expect(described_class.build(root: root).coverage).to be_nil
      end
    end
  end

  it "is a point query, so it may join the hot union" do
    expect(described_class.point_query?).to be(true)
  end
end
