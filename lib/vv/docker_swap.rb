# frozen_string_literal: true
require_relative "docker_swap/version"
require_relative "docker_swap/strategy"
require_relative "docker_swap/sharing_invariant"
require_relative "docker_swap/build_rules"
require_relative "docker_swap/accounting"
require_relative "docker_swap/expectations"

module Vv
  # Layer SWAPPING for closely related Rails services: make the common runtime
  # and common bundle ONE immutable parent image, then build each service image
  # FROM that exact parent digest so Docker stores the shared layers once.
  #
  # Grounding: docs/rails_image_optimization.md.
  module DockerSwap
  end
end
