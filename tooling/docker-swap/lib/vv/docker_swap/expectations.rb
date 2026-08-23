# frozen_string_literal: true
module Vv
  module DockerSwap
    # What layer sharing actually buys -- and the claim not to make for it.
    #
    # The doc is explicit: "Do not expect a large RAM reduction solely from
    # image-layer sharing: it primarily optimizes disk and pull bandwidth. RAM
    # must still be sized for the Rails/Puma processes, workers, and databases
    # that actually run."
    #
    # This module exists so that sentence survives contact with a roadmap.
    module Expectations
      module_function

      OPTIMIZES         = %i[disk pull_bandwidth build_time].freeze
      DOES_NOT_OPTIMIZE = %i[ram cpu request_latency].freeze

      def optimizes?(resource)
        r = resource.to_s.to_sym
        return { ok: true, resource: r, optimized: true,
                 because: "shared read-only layers are stored and pulled once per host" } if OPTIMIZES.include?(r)
        if DOES_NOT_OPTIMIZE.include?(r)
          return { ok: true, resource: r, optimized: false,
                   because: "layer sharing is a storage property; #{r} is still sized by the " \
                            "processes that actually run" }
        end

        { ok: false, reason: :unknown_resource,
          because: "#{resource.inspect} is not a resource this doctrine makes a claim about" }
      end

      # Writable-container-layer discipline: what must NOT accumulate inside a
      # container, because copy-on-write makes those bytes per-container.
      BELONGS_IN_VOLUME_OR_SERVICE = %i[uploads database_data cache queue].freeze
      BELONGS_ON_STDOUT            = %i[logs].freeze

      RULE = "Layer sharing optimizes disk and pull bandwidth, not RAM. Keep logs on stdout and " \
             "uploads, database data, caches, and queues in volumes or external services, or the " \
             "writable container layer grows per container and erases the saving."
    end
  end
end
