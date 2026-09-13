# frozen_string_literal: true

require_relative "self_learn/version"
require_relative "self_learn/refusal"
require_relative "self_learn/wilson"
require_relative "self_learn/operations"
require_relative "self_learn/loop"
require_relative "self_learn/store"
require_relative "self_learn/cpcp"
require_relative "self_learn/engine" if defined?(::Rails::Railtie)

module Vv
  # GOLD → PROD → Bronze collection → Gold recommendations.
  # Plan: docs/architecture/plan_self_learn.md
  #
  # CONTRACT ONLY. Ornith/GRPO/five envelopes are v2 (vv-orinth).
  module SelfLearn
    module_function

    def frame
      "Gold runs in PROD; PROD lands observed Bronze; eval grades with a planned N " \
        "and a Wilson interval; recommend does not promote"
    end
  end
end
