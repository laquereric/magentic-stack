# frozen_string_literal: true

require_relative "nooa/version"
require_relative "nooa/capability"
require_relative "nooa/capabilities"
require_relative "nooa/harness_comparison"
require_relative "nooa/isolation"

# vv-nooa -- models NVIDIA's Object-Oriented Agents (NOOA) harness as
# doctrine-as-data for magentic-stack.
#
# NOOA's thesis: the HARNESS (the software wrapped around the model) moves the
# accuracy-vs-token-cost frontier more than the model does. On the identical model,
# harness design alone produced double-digit accuracy swings and ~half the tokens.
# NVIDIA frames the harness around SIX model-facing capabilities. This gem models
# those six, the published benchmark evidence, and the code-as-action isolation
# doctrine -- each mapped to how magentic-stack realizes it.
#
# This gem does not wrap, import, or execute upstreams/nooa. The pinned Python
# harness is consumed by runtimes/mind-pod; gems/adapters/ is the only code
# allowed to touch upstreams/ (ADR 0020).
#
# Grounding: upstreams/nooa + https://github.com/NVIDIA-NeMo/labs-OO-Agents
module Vv
  module Nooa
    module_function
    def capabilities = Capabilities
    def comparison   = HarnessComparison
    def isolation    = Isolation
  end
end
