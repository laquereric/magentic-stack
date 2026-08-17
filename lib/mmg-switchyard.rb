# frozen_string_literal: true

require_relative "mmg/switchyard/version"
require_relative "mmg/switchyard/outcome"
require_relative "mmg/switchyard/config"
require_relative "mmg/switchyard/observe"
require_relative "mmg/switchyard/router"
require_relative "mmg/switchyard/contract"
require_relative "mmg/switchyard/adapters/source"
require_relative "mmg/switchyard/client"
require_relative "mmg/switchyard/mcb/tool"
require_relative "mmg/switchyard/engine" if defined?(::Rails::Engine)

# mmg-switchyard -- threedot's LLM-assistance plane via NVIDIA Switchyard, for BOTH
# development (syntax/coding help) and runtime assistance. All LLM usage is wrapped in the
# CID Config <-> Switchyard contract; local (MLX) or remote source via the Router; every call
# OTEL-instrumented via Observe (mmg-observe when present). Research + design: docs/.
# Doctrine: CID contract + local policy boundary stay MM-owned; Switchyard is the routing plane ONLY.
# Never-raise.
module Mmg
  module Switchyard
  end
end
