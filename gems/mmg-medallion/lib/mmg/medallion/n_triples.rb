# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # Minimal N-Triples line parser (M1/M2 shared).
    #
    # One line in, one term triple out: `<s> <p> <o> .` with terms as
    # <iri>, "literal", or _:blank. Anything else is not a triple here --
    # bare words, missing dots, and unbalanced quotes fail LOUDLY rather
    # than sliding into the graph as strings that look like nodes.
    # Deliberately not full RDF 1.1 (no datatypes, no language tags, no
    # multi-line literals): the conformer's input contract, not a parser
    # product. Full Turtle stays out of scope.
    module NTriples
      LINE = /\A\s*(\S+)\s+(\S+)\s+(.+?)\s*\.\s*\z/m

      module_function

      def classify(term)
        case term
        when /\A<([^<>]*)>\z/m then { kind: :iri, value: Regexp.last_match(1) }
        when /\A"(.*)"\z/m then { kind: :literal, value: Regexp.last_match(1) }
        when /\A_:(.+)\z/ then { kind: :blank, value: Regexp.last_match(1) }
        else { kind: :bare, value: term }
        end
      end

      def parse(line)
        m = LINE.match(line.to_s)
        unless m
          return { ok: false, because: "not an S P O . line: #{line.to_s.strip[0, 60].inspect}" }
        end

        { ok: true, s: classify(m[1]), p: classify(m[2]), o: classify(m[3]) }
      end
    end
  end
end
