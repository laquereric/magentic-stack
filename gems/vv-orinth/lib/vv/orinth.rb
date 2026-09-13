# frozen_string_literal: true

require_relative "orinth/version"
require_relative "orinth/refusal"
require_relative "orinth/envelopes"
require_relative "orinth/grpo"
require_relative "orinth/v1_binding"
require_relative "orinth/operations"
require_relative "orinth/cpcp"
require_relative "orinth/engine" if defined?(::Rails::Railtie)

module Vv
  # v2 Ornith solver loop. Gem spelling follows the user/filename (orinth);
  # the research model is Ornith (DeepReinforce).
  #
  # Plan: docs/architecture/plan_ornith.md
  # Blocked on v1 plants. GRPO does not promote Gold.
  module Orinth
    module_function

    def frame
      "v2: five observed envelopes and GRPO on a MIND checkpoint; Gold still " \
        "moves only through SelfLearn eval + grant"
    end
  end

  # Research spelling. Same module.
  Ornith = Orinth unless const_defined?(:Ornith, false)
end
