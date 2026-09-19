# frozen_string_literal: true

require_relative "frame/version"
require_relative "frame/parser"
require_relative "frame/placement"
require_relative "frame/concept"
require_relative "frame/bundle"
require_relative "frame/validator"

module Vv
  # vv-frame -- the frame and its decisions, as data an agent can read.
  #
  # The service boundary never raises. Every call answers
  # `{ ok: true, ... }` or `{ ok: false, reason:, because: }`.
  #
  # Two refusals are load-bearing and are enforced by the absence of a method
  # rather than by a check, because the thing you may not do is best made the
  # thing you have no way to do:
  #
  #   R1 - no summarisation. Nothing here rewrites, condenses or paraphrases a
  #        decision. A compacted constraint is a constraint the reader never
  #        saw the original of, which is the defect this gem exists to prevent.
  #        Text is served verbatim or by section, and a budget that cannot fit
  #        a section drops it by name.
  #
  #   R2 - no ranking. Decisions are ordered by path specificity then by id,
  #        both structural. There is no relevance score and no `priority`
  #        field, because the column is the affordance: if one existed,
  #        selection would quietly become judgement.
  module Frame
    REFUSED_OPERATIONS = %i[summarize compact condense paraphrase rank score].freeze

    module_function

    # Load a bundle rooted at a directory holding `frame.md` and `adr/`.
    def load(root)
      Bundle.load(root)
    end

    # Load and gate in one call. A bundle that does not validate is not served,
    # because a knowledge base nobody checks is a memo.
    def load!(root)
      res = load(root)
      return res unless res[:ok]

      v = Validator.call(res[:bundle])
      return { ok: false, reason: :bundle_invalid, because: v[:errors] } unless v[:ok]

      res.merge(validation: v)
    end

    def validate(bundle) = Validator.call(bundle)
  end
end
