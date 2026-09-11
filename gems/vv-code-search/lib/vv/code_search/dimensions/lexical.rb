# frozen_string_literal: true

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
      # What is indexed is TOKENS PER LINE, not trigrams. A trigram index
      # answers "which files contain this substring", which is a file-level
      # question; this gem's unit is a line, and the hot query is "what is on
      # THIS line" rather than "where is this string". Substring search over the
      # corpus remains grep's job on a cold tree.
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

        SKIP_DIRS = %w[.git node_modules tmp log .venv __pycache__ coverage].freeze
        SKIP_EXT = %w[
          .png .jpg .jpeg .gif .ico .pdf .zip .gz .tgz .bz2 .xz .7z
          .woff .woff2 .ttf .eot .otf .mp4 .mov .mp3 .wav .so .dylib .o .a .class .jar
        ].freeze

        class << self
          def name = :lexical

          def point_query? = true

          def build(root:)
            postings = {}
            coverage = []
            each_text_file(root) do |relative, absolute|
              lines = tokenise(absolute)
              coverage << relative
              postings[relative] = lines unless lines.empty?
            end
            # Coverage is explicit: this dimension skips binaries and minified
            # lines, so it is NOT entitled to report absence outside what it
            # read.
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
