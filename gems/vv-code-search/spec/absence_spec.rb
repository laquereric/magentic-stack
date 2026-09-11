# frozen_string_literal: true

# The grep lesson, which is the reason this gem is allowed to exist beside `rg`
# rather than instead of it.
#
# plan_vv-code-search: "Absence must be a signal. `rg LegacyPaymentProcessor` -> 0
# hits is evidence. An index miss can mean 'not indexed.'" An index that cannot
# tell those apart is strictly worse than the grep it replaces, because it
# returns the same empty array for "I looked and it is not there" and "I never
# looked", and a caller cannot act on the difference it cannot see.
RSpec.describe "absence is a signal" do
  let(:corpus) do
    {
      "Gemfile.lock" => "GEM\n  specs:\n    rake (13.0.6)\n\nDEPENDENCIES\n  rake\n",
      "app/plain.rb" => "class Plain\n  def call = :ok\nend\n"
    }
  end

  it "refuses a lookup with no index at all rather than returning empty hits" do
    result = Vv::CodeSearch::Lookup.call(index: nil, path: "anything.rb", line: 1)

    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq("not_indexed")
  end

  it "returns ok with an EMPTY pin list for an indexed line that has no pin" do
    # This is the case the plan names directly: "Lookup of an indexed rev with
    # no pin on that line is ok:true with pins: [] (absence is a signal)."
    with_corpus(corpus) do |root|
      with_store do |store|
        built = Vv::CodeSearch::Index.build(
          repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
        )
        result = Vv::CodeSearch::Lookup.call(index: built[:index], path: "app/plain.rb", line: 2)

        expect(result[:ok]).to be(true)
        expect(result.dig(:dimensions, :pins)).to eq(indexed: true, hits: [])
      end
    end
  end

  it "separates 'this dimension was never built' from 'this dimension found nothing'" do
    with_corpus(corpus) do |root|
      with_store do |store|
        # magentic-pins builds ONLY pins, so lexical is unbuilt here.
        pins_only = Vv::CodeSearch::Index.build(
          repo: "demo", rev: "rev1", schema: "magentic-pins", root: root, store: store
        )[:index]

        answer = Vv::CodeSearch::Lookup.call(
          index: pins_only, path: "app/plain.rb", line: 2, dimensions: [:pins]
        )
        expect(answer.dig(:dimensions, :pins, :indexed)).to be(true)

        # And asking a schema for a dimension it does not name is a typed
        # refusal, not an empty answer that reads like evidence.
        missing = Vv::CodeSearch::Lookup.call(
          index: pins_only, path: "app/plain.rb", line: 2, dimensions: [:lexical]
        )
        expect(missing[:ok]).to be(false)
        expect(missing[:reason]).to eq("no_such_dimension")
      end
    end
  end

  it "refuses to call silence evidence in a file the lexical dimension never read" do
    # A binary is skipped by the lexical walk. A token miss inside it is not
    # proof the token is absent, and the envelope says so instead of shrugging
    # with an empty array.
    with_corpus(corpus.merge("assets/logo.png" => "\x89PNG\r\n\x1a\n\x00binary")) do |root|
      with_store do |store|
        index = Vv::CodeSearch::Index.build(
          repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
        )[:index]

        skipped = Vv::CodeSearch::Lookup.call(index: index, path: "assets/logo.png", line: 1)
        expect(skipped.dig(:dimensions, :lexical, :indexed)).to be(false)
        expect(skipped.dig(:dimensions, :lexical, :because)).to include("silence here is not evidence")

        # While a file it DID read reports real absence on an empty line.
        read = Vv::CodeSearch::Lookup.call(index: index, path: "app/plain.rb", line: 3)
        expect(read.dig(:dimensions, :lexical, :indexed)).to be(true)
      end
    end
  end

  it "reports a line past the end of a read file as absence, not as an error" do
    with_corpus(corpus) do |root|
      with_store do |store|
        index = Vv::CodeSearch::Index.build(
          repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
        )[:index]

        result = Vv::CodeSearch::Lookup.call(index: index, path: "app/plain.rb", line: 9_999)
        expect(result[:ok]).to be(true)
        expect(result.dig(:dimensions, :lexical, :hits)).to eq([])
      end
    end
  end

  it "refuses a line number that is not a positive integer" do
    with_corpus(corpus) do |root|
      with_store do |store|
        index = Vv::CodeSearch::Index.build(
          repo: "demo", rev: "rev1", schema: "magentic", root: root, store: store
        )[:index]

        expect(Vv::CodeSearch::Lookup.call(index: index, path: "app/plain.rb", line: 0)[:reason])
          .to eq("bad_line")
        expect(Vv::CodeSearch::Lookup.call(index: index, path: "app/plain.rb", line: "nope")[:reason])
          .to eq("bad_line")
      end
    end
  end
end
