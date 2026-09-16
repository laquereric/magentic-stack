# frozen_string_literal: true

require_relative "../tgrep"

module Vv
  module CodeSearch
    module Dimensions
      # Stage 2: the grep primitive, indexed rather than replaced.
      #
      # plan_vv-code-search is explicit that lexical search stays, and gives the
      # article's two reasons: dropping it loses DISCOVERY (a vague question has
      # no symbol yet, so there is nothing for an LSP to navigate to) and it
      # loses TRUE ABSENCE (`rg LegacyPaymentProcessor` returning nothing is
      # evidence; an index miss may only mean "not indexed").
      #
      # The second reason is the one that shapes this file. This dimension is
      # only allowed to report absence as evidence for files it actually read,
      # so it records its own coverage -- which paths were indexed -- and Lookup
      # uses that to tell "indexed, no hits" from "never indexed". A lexical
      # index that cannot say which files it covers turns every miss into a
      # maybe, which is strictly worse than grep.
      #
      # TWO INDICES, ONE DIMENSION. The hover asks "what is on THIS line" and
      # that is still TOKENS PER LINE, a hash probe, no process. The discovery
      # question -- "where is this string" -- is microsoft/tgrep's trigram
      # index, built at ingest into the same content-addressed store, and
      # answered by Lookup.search. Coverage prefers tgrep's file list when an
      # index was built, so a token miss and a tgrep miss agree about which
      # files were looked at. The walker below is the fallback for a host with
      # no tgrep binary, not a second opinion.
      class Lexical < Dimension
        # Identifier-shaped runs, plus the dotted/slashed/colon forms that config
        # keys and topic names actually take. PAYMENT_TIMEOUT, payment.timeout,
        # kafka/payments, and Rails::Engine all have to survive tokenisation or
        # the config-and-comment half of the corpus -- the part the article says
        # the AST cannot see -- is not searchable here.
        TOKEN = /[A-Za-z_][A-Za-z0-9_]*(?:[.\/:\-][A-Za-z0-9_]+)*|\d[\w.]*/.freeze

        # A line longer than this is minified output, a data blob, or a vendored
        # bundle. Indexing it costs more than it returns and its "tokens" are
        # not vocabulary anyone searches for.
        MAX_LINE = 2_000

        # Binary sniffing, cheaply: a NUL byte in the first block.
        PROBE_BYTES = 8_000

        SKIP_DIRS = %w[.git node_modules tmp log .venv __pycache__ coverage .tgrep].freeze
        SKIP_EXT = %w[
          .png .jpg .jpeg .gif .ico .pdf .zip .gz .tgz .bz2 .xz .7z
          .woff .woff2 .ttf .eot .otf .mp4 .mov .mp3 .wav .so .dylib .o .a .class .jar
        ].freeze

        class << self
          def name = :lexical

          def point_query? = true

          def build(root:, tgrep_index: nil, **_)
            postings = {}
            coverage = []
            listed = tgrep_index && Tgrep.available? ? Tgrep.files(root: root, index_path: tgrep_index) : nil
            if listed && listed[:ok]
              listed[:paths].each do |relative|
                absolute = File.join(root, relative)
                next unless File.file?(absolute)

                lines = tokenise(absolute)
                coverage << relative
                postings[relative] = lines unless lines.empty?
              end
            else
              each_text_file(root) do |relative, absolute|
                lines = tokenise(absolute)
                coverage << relative
                postings[relative] = lines unless lines.empty?
              end
            end
            # Coverage is explicit: this dimension skips binaries and minified
            # lines, so it is NOT entitled to report absence outside what it
            # read. When tgrep listed the files, coverage is tgrep's list, so a
            # hover miss and a search miss agree about what was looked at.
            Built.new(postings: normalise(postings), coverage: coverage.sort)
          end

          def each_text_file(root)
            root = File.expand_path(root)
            stack = [root]
            while (dir = stack.pop)
              Dir.children(dir).each do |child|
                next if SKIP_DIRS.include?(child)

                absolute = File.join(dir, child)
                if File.directory?(absolute)
                  stack << absolute unless File.symlink?(absolute)
                  next
                end
                next if SKIP_EXT.include?(File.extname(child).downcase)
                next unless text?(absolute)

                yield absolute.delete_prefix("#{root}/"), absolute
              end
            end
          end

          def text?(path)
            head = File.binread(path, PROBE_BYTES)
            head.nil? || !head.include?("\x00")
          rescue SystemCallError, IOError
            false
          end

          def tokenise(path)
            out = {}
            File.foreach(path, encoding: "UTF-8") .with_index(1) do |line, no|
              next if line.bytesize > MAX_LINE

              tokens = line.scan(TOKEN)
              out[no] = tokens.uniq unless tokens.empty?
            end
            out
          rescue SystemCallError, IOError, ArgumentError
            {}
          end
        end
      end
    end
  end
end
