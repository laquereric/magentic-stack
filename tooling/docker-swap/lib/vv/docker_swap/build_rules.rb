# frozen_string_literal: true
module Vv
  module DockerSwap
    # The three build-time mistakes that quietly cost you the swap, expressed
    # over a structured build plan rather than by parsing Dockerfile text.
    #
    #   1. Dependency copy must precede source copy, or an ordinary source edit
    #      re-runs bundle install and rebuilds the gem layer every time.
    #   2. Build-only packages must be purged in the SAME RUN step that installs
    #      them. A purge in a later step does not shrink the image: the earlier
    #      layer already committed those bytes.
    #   3. The parent must be digest-pinned (see SharingInvariant).
    #
    # Source: docs/rails_image_optimization.md sections 3 and 4.
    module BuildRules
      module_function

      # kind: :from | :copy_dependencies | :copy_source | :run
      # installs/purges apply to :run only.
      Step = Struct.new(:kind, :installs, :purges, keyword_init: true)

      KINDS = %i[from copy_dependencies copy_source run].freeze

      # Packages that exist only to compile native gems. Present at runtime they
      # are dead weight and extra attack surface.
      BUILD_ONLY = %w[build-essential pkg-config libpq-dev libyaml-dev
                      libffi-dev libxml2-dev libxslt1-dev cmake git].freeze

      # Kept because the running application links against them.
      RUNTIME = %w[ca-certificates curl libpq5 libyaml-0-2 libffi8 tzdata].freeze

      DOCKERIGNORE_BASELINE = %w[
        .git .github log/* tmp/* coverage/ spec/ test/ features/
        node_modules/ vendor/bundle/ vendor/cache/ public/assets/ public/packs/
        .env .env.* Dockerfile* docker-compose*.yml README.md
      ].freeze

      def classify_package(pkg)
        p = pkg.to_s
        return { ok: true, package: p, kind: :build_only } if BUILD_ONLY.include?(p)
        return { ok: true, package: p, kind: :runtime }    if RUNTIME.include?(p)

        { ok: false, reason: :unknown_package,
          because: "#{p.inspect} is in neither BUILD_ONLY nor RUNTIME; classify it before " \
                   "deciding whether it may survive into the runtime image" }
      end

      # Does dependency installation happen before source is copied?
      def cache_order_ok?(steps)
        list = Array(steps)
        deps = list.index { |s| s.kind == :copy_dependencies }
        src  = list.index { |s| s.kind == :copy_source }

        if deps.nil?
          return { ok: false, reason: :no_dependency_copy,
                   because: "no :copy_dependencies step; Gemfile and Gemfile.lock must be copied " \
                            "on their own before the source so the gem layer can be cached" }
        end
        return { ok: true, ordered: true, because: "no :copy_source step to invalidate the gem layer" } if src.nil?

        if deps < src
          { ok: true, ordered: true,
            because: "dependencies are copied at step #{deps}, before source at step #{src}" }
        else
          { ok: true, ordered: false,
            because: "source is copied at step #{src}, before dependencies at step #{deps}; " \
                     "every ordinary source edit will invalidate the cache and re-run bundle install" }
        end
      end

      # Build-only packages installed in a RUN step that does not purge them in
      # that same step. Returns one finding per leak.
      def leaked_build_packages(steps)
        Array(steps).each_with_index.flat_map do |step, idx|
          next [] unless step.kind == :run

          purged = Array(step.purges).map(&:to_s)
          Array(step.installs).map(&:to_s).select { |p| BUILD_ONLY.include?(p) }.reject { |p| purged.include?(p) }
                              .map do |p|
            { rule: :build_package_committed, step: idx, package: p,
              because: "#{p} is installed at step #{idx} and not purged in that same RUN; " \
                       "its bytes are already committed to that layer and a later purge cannot reclaim them" }
          end
        end
      end

      RULE = "Copy Gemfile and Gemfile.lock before application source, and purge build-only " \
             "packages inside the same RUN that installs them. A later cleanup step adds a layer; " \
             "it does not remove the bytes an earlier layer already committed."
    end
  end
end
