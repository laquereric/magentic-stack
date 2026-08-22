# frozen_string_literal: true
module Vv
  module DockerSwap
    # Which of the two designs to use for a family of closely related Rails
    # services. Source: docs/rails_image_optimization.md ("Choose between two
    # designs").
    #
    #   :superset    -- ONE image for all services. Best possible storage
    #                   result; every service carries the others' optional gems
    #                   and they all deploy together.
    #   :common_base -- an immutable common parent + thin service children.
    #                   Nearly as good; costs a maintained common Gemfile/lock
    #                   contract, buys independent release.
    module Strategy
      module_function

      DESIGNS = %i[superset common_base].freeze

      # The doc's threshold for "differ only by one to three gems".
      MODEST_DELTA = 3

      # Never-raise choice between the two designs.
      #
      # @param delta_gem_count [Integer] gems a service adds beyond the common set
      # @param conflicting_dependencies [Boolean] do the delta gems conflict?
      # @param independent_release_required [Boolean] must services version,
      #   secure, or deploy on separate cadences?
      def choose(delta_gem_count:, conflicting_dependencies:, independent_release_required:)
        unless delta_gem_count.is_a?(Integer) && delta_gem_count >= 0
          return { ok: false, reason: :invalid_delta_gem_count,
                   because: "delta_gem_count must be a non-negative Integer, got #{delta_gem_count.inspect}" }
        end

        if independent_release_required
          return design(:common_base,
                        "services must be released independently; a superset image forces them to deploy together")
        end
        if conflicting_dependencies
          return design(:common_base,
                        "the delta gems have conflicting dependencies, so a single superset bundle cannot resolve")
        end
        if delta_gem_count > MODEST_DELTA
          return design(:common_base,
                        "delta of #{delta_gem_count} gems exceeds the modest threshold of #{MODEST_DELTA}")
        end

        design(:superset,
               "delta of #{delta_gem_count} non-conflicting gems is modest and services may release together")
      end

      def design(name, because)
        { ok: true, design: name, because: because }
      end
      private_class_method :design
    end
  end
end
