# frozen_string_literal: true

module Vv
  module CodeSearch
    # The cheap half: one line, every enabled dimension, under a second.
    #
    # This is the product. plan_vv-code-search puts the bound on THIS call --
    # "measured at lookup, not at index" -- because it is what makes the index
    # usable as in-editor feedback and as an SLM step rather than as a
    # frontier-agent exploration. Indexing the tree slowly is fine. Answering
    # slowly is not.
    #
    # So `call` does exactly one thing per dimension: probe a Hash that is
    # already in memory. No file is opened, no process is spawned, no model is
    # called. If a future dimension cannot be answered that way it does not
    # belong here; Schema.register refuses it at the door.
    #
    # `search` is the other half of lexical: a pattern against the tgrep
    # trigram corpus. It is allowed to spawn. It is not on the hover path and
    # carries no sub-second promise of the same kind -- tgrep's own bound is
    # "milliseconds on a warm index", which is why we built the index at ingest
    # rather than shelling out to `rg` on every turn.
    #
    # ABSENCE IS A SIGNAL, and this is where that is kept honest. Three outcomes
    # are distinct and a caller can tell them apart without parsing prose:
    #
    #   {ok: false, reason: "not_indexed"}       nothing was ever built for this rev
    #   {indexed: false, because: ...}           this DIMENSION was not built, or
    #                                            was built but never read this file
    #   {indexed: true, hits: []}                it looked, and there is nothing
    #
    # The third is evidence. The first two are not, and collapsing them into an
    # empty list is the failure mode the article names: an index miss that reads
    # like a real "this does not exist".
    module Lookup
      module_function

      def call(index:, path:, line:, dimensions: nil)
        Envelope.never_raise do
          return Envelope.refuse("not_indexed", "no index was supplied for this (repo, fork, rev, schema)") if index.nil?

          # Converted defensively rather than by letting Integer() raise into
          # the never_raise wrapper above. That wrapper reports index_corrupt,
          # which is the wrong diagnosis for a caller's bad argument and would
          # send someone looking at the store for a fault that is in their call.
          line_no = begin
            Integer(line)
          rescue ArgumentError, TypeError
            nil
          end
          if line_no.nil? || !line_no.positive?
            return Envelope.refuse("bad_line", "line #{line.inspect} is not a positive integer")
          end

          wanted = dimensions ? Array(dimensions).map(&:to_sym) : index.schema.names
          unknown = wanted - index.schema.names
          unless unknown.empty?
            return Envelope.refuse(
              "no_such_dimension",
              "schema #{index.schema.id} names #{index.schema.names.join(', ')}; asked for #{unknown.join(', ')}"
            )
          end

          answers = wanted.each_with_object({}) do |name, out|
            out[name] = answer(index, name, path, line_no)
          end

          Envelope.ok(
            line: { repo: index.repo, fork: index.fork_name, rev: index.rev, path: path, line: line_no },
            dimensions: answers
          )
        end
      end

      def answer(index, name, path, line_no)
        unless index.built?(name)
          return {
            indexed: false,
            because: "dimension #{name} was not built for #{index.rev} under schema #{index.schema.id}"
          }
        end

        unless index.covers?(name, path)
          return {
            indexed: false,
            because: "#{name} did not read #{path}; silence here is not evidence"
          }
        end

        hits = index.postings.dig(name, path, line_no) || []
        { indexed: true, hits: hits }
      end

      # The reverse question, and the reason DECLARES and REFERENCES are kept
      # apart in the pins dimension: "this pin moved -- which lines care?"
      #
      # A maintainer looking at an incoming PR wants the reference set, not just
      # the declaration site. The declaration is where you change the version;
      # the references are what you have to re-check because it changed, and
      # those are the lines a review actually has to visit.
      #
      # This is a SCAN over one dimension's postings, which is why it is not part
      # of `call` and carries no sub-second promise. It is a batch question that
      # happens to be cheap at this corpus size; if it ever stops being cheap it
      # gets its own inverted index rather than a place in the hot union.
      def lines_for_pin(index:, pin:, kinds: %w[declares references])
        Envelope.never_raise do
          return Envelope.refuse("not_indexed", "no index supplied") if index.nil?
          return Envelope.refuse("no_such_dimension", "schema #{index.schema.id} has no pins dimension") unless index.schema.names.include?(:pins)
          return Envelope.refuse("not_indexed", "pins was not built for #{index.rev}") unless index.built?(:pins)

          found = []
          index.postings.fetch(:pins, {}).each do |path, lines|
            lines.each do |line_no, entries|
              entries.each do |entry|
                next unless kinds.include?(entry["kind"])
                next unless entry["pin"] == pin || entry["name"] == pin

                found << { path: path, line: line_no, kind: entry["kind"], pin: entry["pin"], source: entry["source"] }
              end
            end
          end

          Envelope.ok(pin: pin, lines: found.sort_by { |h| [h[:path], h[:line]] })
        end
      end

      # Corpus search over the tgrep trigram index built at ingest.
      #
      # This is the discovery question the article names -- a vague query has
      # no symbol yet -- answered against a tree we already host, so the second
      # lookup is not another `rg` of the whole monorepo. Absence is still a
      # signal: zero matches with a built corpus is evidence; a missing binary
      # or a missing corpus is a typed refusal, not an empty list.
      #
      # Defaults to a literal (`-F`) pattern. A regex is opt-in because a
      # symbol the user typed is the common case, and an unescaped `Vec<T>` is
      # how agents search the wrong thing. See tgrep AGENTS.md.
      def search(index:, pattern:, root: nil, fixed_strings: true, ignore_case: false, glob: nil, max_count: nil)
        Envelope.never_raise do
          return Envelope.refuse("not_indexed", "no index was supplied for this (repo, fork, rev, schema)") if index.nil?
          if pattern.nil? || pattern.to_s.empty?
            return Envelope.refuse("bad_pattern", "a search pattern is required")
          end
          unless index.tgrep_indexed?
            return Envelope.refuse(
              "tgrep_missing",
              "no tgrep corpus was built for #{index.rev} under schema #{index.schema.id}; " \
              "silence here is not evidence"
            )
          end

          tree = root || index.root
          if tree.nil? || !File.directory?(tree)
            return Envelope.refuse(
              "tgrep_failed",
              "tgrep needs the source tree to verify candidates; pass root: or rebuild the index"
            )
          end

          result = Tgrep.search(
            pattern: pattern,
            root: tree,
            index_path: index.tgrep_dir,
            fixed_strings: fixed_strings,
            ignore_case: ignore_case,
            glob: glob,
            max_count: max_count
          )
          return result unless result[:ok]

          Envelope.ok(
            pattern: pattern.to_s,
            line: { repo: index.repo, fork: index.fork_name, rev: index.rev },
            matches: result[:matches],
            indexed: true
          )
        end
      end
    end
  end
end
