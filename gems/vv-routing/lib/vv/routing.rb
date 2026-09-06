# frozen_string_literal: true

require_relative "routing/version"
require_relative "routing/plane"
require_relative "routing/tier"
require_relative "routing/route"
require_relative "routing/prefix"

# Two-tier LLM routing, split by the question the literature leaves out: is this
# call on the SYNTHESIS plane, where a toolchain reads the output before anyone
# depends on it, or the PRODUCTION plane, where nothing does?
module Vv
  module Routing
  end
end
