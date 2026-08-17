# frozen_string_literal: true
module Mmg
  module Switchyard
    # Route an assistance call to a LOCAL (MLX) or REMOTE LLM source per policy
    # (latency / cost / privacy / capability) + the trust-ladder + private-vs-portable-data
    # doctrine (which prompts/data may leave the device). TODO(grok): real policy from the memo.
    module Router
      module_function
      def choose(config)
        config&.source || :local
      end
    end
  end
end
