# frozen_string_literal: true

# microsoft/tgrep is the trigram half of lexical. Tokens-per-line still answer
# the hover; this file is the discovery question -- where is this string --
# and the refusals that keep a missing binary from looking like evidence.
RSpec.describe "tgrep is the lexical search engine" do
  let(:corpus) do
    {
      "Gemfile.lock" => "GEM\n  specs:\n    rake (13.0.6)\n\nDEPENDENCIES\n  rake\n",
      "app/plain.rb" => "class Plain\n  def call = :ok\nend\n",
      "app/notes.md" => "LegacyPaymentProcessor lives in comments only.\n"
    }
  end

  it "builds a trigram corpus into the content-addressed store when tgrep is present" do
    with_tgrep do
      with_corpus(corpus) do |root|
        with_store do |store|
          built = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
          )

          expect(built[:ok]).to be(true), -> { built.inspect }
          expect(built.dig(:tgrep, "indexed")).to be(true)
          expect(built[:index].tgrep_indexed?).to be(true)
          expect(File.file?(File.join(built[:index].tgrep_dir, "lookup.bin"))).to be(true)

          opened = Vv::CodeSearch::Index.open(digest: built[:digest], store: store)
          expect(opened[:index].tgrep_indexed?).to be(true)
        end
      end
    end
  end

  it "does not build a trigram corpus for a pins-only schema" do
    with_tgrep do
      with_corpus(corpus) do |root|
        with_store do |store|
          built = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic-pins", root: root, store: store
          )

          expect(built[:ok]).to be(true)
          expect(built[:tgrep]).to be_nil
          expect(built[:index].tgrep_indexed?).to be(false)
        end
      end
    end
  end

  it "finds a literal in the corpus and reports path plus line" do
    with_tgrep do
      with_corpus(corpus) do |root|
        with_store do |store|
          index = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
          )[:index]

          found = Vv::CodeSearch::Lookup.search(index: index, pattern: "LegacyPaymentProcessor")
          expect(found[:ok]).to be(true), -> { found.inspect }
          expect(found[:indexed]).to be(true)
          expect(found[:matches].map { |m| [m["path"], m["line"]] }).to eq(
            [["app/notes.md", 1]]
          )
        end
      end
    end
  end

  it "reports zero matches as evidence, not as an error" do
    with_tgrep do
      with_corpus(corpus) do |root|
        with_store do |store|
          index = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
          )[:index]

          missed = Vv::CodeSearch::Lookup.search(index: index, pattern: "DefinitelyNotInThisTree")
          expect(missed[:ok]).to be(true)
          expect(missed[:indexed]).to be(true)
          expect(missed[:matches]).to eq([])
        end
      end
    end
  end

  it "refuses a missing trigram corpus rather than returning empty hits" do
    without_tgrep do
      with_corpus(corpus) do |root|
        with_store do |store|
          index = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
          )[:index]

          expect(index.tgrep_indexed?).to be(false)
          result = Vv::CodeSearch::Lookup.search(index: index, pattern: "Plain")
          expect(result[:ok]).to be(false)
          expect(result[:reason]).to eq("tgrep_missing")
        end
      end
    end
  end

  it "refuses a search with no index the same way Lookup.call does" do
    result = Vv::CodeSearch::Lookup.search(index: nil, pattern: "anything")
    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq("not_indexed")
  end

  it "refuses an empty pattern" do
    with_tgrep do
      with_corpus(corpus) do |root|
        with_store do |store|
          index = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic-pins", root: root, store: store
          )[:index]

          expect(Vv::CodeSearch::Lookup.search(index: index, pattern: "")[:reason]).to eq("bad_pattern")
        end
      end
    end
  end

  it "keeps the hover as a hash probe: tokens still land on the line" do
    with_tgrep do
      with_corpus(corpus) do |root|
        with_store do |store|
          index = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
          )[:index]

          hover = Vv::CodeSearch::Lookup.call(index: index, path: "app/plain.rb", line: 1)
          expect(hover[:ok]).to be(true)
          expect(hover.dig(:dimensions, :lexical, :indexed)).to be(true)
          expect(hover.dig(:dimensions, :lexical, :hits)).to include("Plain")
        end
      end
    end
  end

  it "skips a binary in both tgrep coverage and the lexical hover" do
    with_tgrep do
      with_corpus(corpus.merge("assets/logo.png" => "\x89PNG\r\n\x1a\n\x00binary")) do |root|
        with_store do |store|
          index = Vv::CodeSearch::Index.build(
            repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
          )[:index]

          skipped = Vv::CodeSearch::Lookup.call(index: index, path: "assets/logo.png", line: 1)
          expect(skipped.dig(:dimensions, :lexical, :indexed)).to be(false)

          found = Vv::CodeSearch::Lookup.search(index: index, pattern: "PNG")
          expect(found[:ok]).to be(true)
          expect(found[:matches]).to eq([])
        end
      end
    end
  end
end
