# frozen_string_literal: true

module Vv
  module CodeSearch
    # What a dimension has to be to join the hot union.
    #
    # plan_vv-code-search puts a hard bound on lookup -- under a second per line,
    # across every enabled dimension -- and then says what to do with a dimension
    # that cannot meet it: "If a dimension cannot answer by line in < 1 s, it is
    # not in the hot union; it stays batch."
    #
    # That is enforced here as a declared property rather than measured per call,
    # because measuring it per call is already too late: the hover has blown its
    # budget by the time you find out. A dimension declares `point_query?`, the
    # schema refuses to admit one that answers false, and a gate plants a
    # scan-shaped dimension to prove the refusal is real.
    #
    # A dimension supplies:
    #   name          symbol, the key it occupies in the result
    #   point_query?  may it join the hot union
    #   build(root:)  => Built(postings:, coverage:)
    #
    # `build` runs at INDEX time, which is the expensive half and is allowed to
    # be. Nothing in this class runs at lookup.
    #
    # COVERAGE is the second half of the grep lesson. `nil` means the dimension
    # read the whole tree, so silence on any line is real absence. An Array of
    # paths means it read only those, and silence anywhere else is not evidence
    # of anything -- Lexical skips binaries and minified lines, and a token miss
    # inside a file it never opened must not be reported as "this token is not
    # here". A dimension that cannot say what it covered can only offer maybes,
    # which is strictly worse than the `rg` it was supposed to replace.
    Built = Struct.new(:postings, :coverage, keyword_init: true)

    class Dimension
      class << self
        def name
          raise NotImplementedError, "#{self} must name itself"
        end

        # Answered by a point query on a per-line posting list, not by a scan.
        # Default is false: a new dimension is batch until it proves otherwise,
        # because the failure mode of the opposite default is a hover that
        # silently starts taking four seconds.
        def point_query?
          false
        end

        def build(root:)
          raise NotImplementedError, "#{self} must build postings"
        end

        # Postings are serialised as { path => { "line" => [entries] } }. JSON
        # object keys are strings, so line numbers survive the round trip as
        # strings; this is the one place that is normalised, so no caller has to
        # remember it.
        def normalise(postings)
          out = {}
          postings.each do |path, lines|
            next if lines.nil? || lines.empty?

            out[path] = lines.each_with_object({}) do |(line, entries), acc|
              acc[Integer(line)] = Array(entries)
            end
          end
          out
        end
      end
    end
  end
end
