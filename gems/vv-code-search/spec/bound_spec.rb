# frozen_string_literal: true

# The product is the bound. plan_vv-code-search: "After the indices exist,
# per-line lookup across every indexed dimension is < 1 second. That bound is
# the product. It is what makes the index usable as in-editor feedback and as a
# fast SLM step rather than a frontier-agent exploration."
#
# So it is measured, on the real monorepo, rather than asserted. A benchmark
# over a six-file fixture would pass while proving nothing about the corpus this
# gem exists to serve.
RSpec.describe "the < 1 s bound" do
  BOUND_SECONDS = 1.0

  # Indexing is allowed to be slow; this is the expensive half by design. It is
  # built once for the whole file.
  before(:all) do
    @store = Dir.mktmpdir("vv-code-search-bound")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @built = Vv::CodeSearch::Index.build(
      repo: "magentic-stack",
      rev: "spec",
      schema: "magentic",
      root: CorpusHelpers::REPO_ROOT,
      store: @store
    )
    @index_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  after(:all) { FileUtils.remove_entry(@store) if @store && Dir.exist?(@store) }

  it "indexes the real repo and reports what it indexed" do
    expect(@built[:ok]).to be(true), -> { "index failed: #{@built.inspect}" }

    counts = @built[:lines_indexed]
    # An empty index would pass every timing assertion below while having
    # measured nothing, which is the shape of pseudo validation this repo has a
    # standing rule against.
    expect(counts[:pins]).to be > 100
    expect(counts[:lexical]).to be > 10_000

    puts format(
      "\n    corpus: %<lex>d lexical lines, %<pin>d pin lines, indexed in %<sec>.1f s",
      lex: counts[:lexical], pin: counts[:pins], sec: @index_seconds
    )
  end

  it "answers a warm per-line lookup across every enabled dimension well under a second (p95)" do
    open_result = Vv::CodeSearch::Index.open(digest: @built[:digest], store: @store)
    expect(open_result[:ok]).to be(true)
    index = open_result[:index]

    # A spread of real lines: a lockfile (pin-dense), a pin manifest, a compose
    # file, and ordinary source. Sampling only empty lines would measure the
    # fast path and call it the bound.
    targets = [
      ["Gemfile.lock", 12],
      ["upstreams/manifests/nooa.pin.json", 5],
      ["runtimes/mind-pod/app/extract/compose.yml", 20],
      ["gems/vv-code-search/lib/vv/code_search/lookup.rb", 30],
      [".gitmodules", 2]
    ]

    samples = []
    300.times do |i|
      path, line = targets[i % targets.size]
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = Vv::CodeSearch::Lookup.call(index: index, path: path, line: line)
      samples << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
      expect(result[:ok]).to be(true)
    end

    sorted = samples.sort
    p95 = sorted[(sorted.size * 0.95).floor]
    puts format("    lookup p95: %.3f ms over %d samples", p95 * 1_000, samples.size)

    expect(p95).to be < BOUND_SECONDS
  end

  it "finds real pins on real lines of this repo" do
    index = Vv::CodeSearch::Index.open(digest: @built[:digest], store: @store)[:index]

    # The Milvus digest pin added with the rag container. If this stops being a
    # pin the assertion should fail loudly rather than silently measure nothing.
    found = Vv::CodeSearch::Lookup.lines_for_pin(index: index, pin: "milvusdb/milvus")
    expect(found[:ok]).to be(true)
    expect(found[:lines]).not_to be_empty
    expect(found[:lines].map { |l| l[:path] }).to include(
      "runtimes/mind-pod/app/extract/compose.yml"
    )
  end

  it "answers the reverse question with references, not only declarations" do
    index = Vv::CodeSearch::Index.open(digest: @built[:digest], store: @store)[:index]

    declares = Vv::CodeSearch::Lookup.lines_for_pin(index: index, pin: "rspec", kinds: ["declares"])
    references = Vv::CodeSearch::Lookup.lines_for_pin(index: index, pin: "rspec", kinds: ["references"])

    expect(declares[:lines]).not_to be_empty
    expect(references[:lines]).not_to be_empty

    # The property that is actually true here, and the one worth keeping: the
    # two sets are DISJOINT. No line both decides a version and merely cares
    # about it.
    #
    # Not "references outnumber declarations" -- measured against this repo,
    # they are equal, because a Bundler lockfile contributes exactly one specs
    # line and one DEPENDENCIES line per gem. The reverse question is answered
    # by the UNION being strictly larger than either half, which is what a
    # maintainer gets that a naive "find the version" grep does not.
    declared_at = declares[:lines].map { |l| [l[:path], l[:line]] }
    referenced_at = references[:lines].map { |l| [l[:path], l[:line]] }

    expect(declared_at & referenced_at).to be_empty
    expect((declared_at | referenced_at).size).to be > declared_at.size
    expect((declared_at | referenced_at).size).to be > referenced_at.size
  end
end
