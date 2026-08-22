# frozen_string_literal: true
module Vv
  module DockerSwap
    # THE load-bearing rule. From docs/rails_image_optimization.md:
    #
    #   "The key is not merely having similar Dockerfiles. Every service must
    #    inherit from the SAME PARENT IMAGE DIGEST and must preserve exactly the
    #    same gem versions for common dependencies."
    #
    # Both halves fail SILENTLY: similar-looking Dockerfiles still build, a
    # drifted common gem still resolves, and you simply do not get the sharing
    # you designed for. This module makes the failure loud and specific.
    module SharingInvariant
      module_function

      # A service image as declared, not as built.
      #   parent  -- what its Dockerfile says FROM
      #   commons -- resolved versions of the COMMON gem set only
      Image = Struct.new(:name, :parent, :commons, keyword_init: true)

      # A parent reference pins a digest only in the sha256: form. A tag --
      # including :latest and any human-readable release tag -- is floating: the
      # bytes behind it can change without the child Dockerfile changing.
      DIGEST_RE = /\Asha256:[0-9a-f]{64}\z/i

      def digest?(parent)
        s = parent.to_s
        return true if s.match?(DIGEST_RE)
        # registry.example.com/acme/rails-common@sha256:<64 hex>
        !!(s.split("@", 2)[1]&.match?(DIGEST_RE))
      end

      # Will these images actually share their common layers?
      # Returns { ok: true, shares: true|false, violations: [...] }.
      # Each violation is { rule:, because:, ... }; `shares` is true iff empty.
      def verify(images)
        list = Array(images)
        if list.size < 2
          return { ok: false, reason: :not_enough_images,
                   because: "sharing is a property of two or more images, got #{list.size}" }
        end

        violations = []
        violations.concat(floating_parents(list))
        violations.concat(parent_mismatch(list))
        violations.concat(common_gem_drift(list))

        { ok: true, shares: violations.empty?, violations: violations }
      end

      def floating_parents(list)
        list.reject { |i| digest?(i.parent) }.map do |i|
          { rule: :floating_parent_tag, image: i.name, parent: i.parent,
            because: "#{i.name} inherits from a floating tag (#{i.parent}); " \
                     "pin the parent by digest so the shared layers cannot change underneath it" }
        end
      end

      def parent_mismatch(list)
        parents = list.map(&:parent).uniq
        return [] if parents.size <= 1

        [{ rule: :parent_digest_mismatch, parents: parents,
           because: "images inherit from #{parents.size} different parents, so their base and " \
                    "common-gem layers are distinct and stored once EACH: #{parents.join(', ')}" }]
      end

      # A gem is "common" only if every image declares it. Any gem that every
      # image declares but at differing versions breaks the shared bundle layer.
      def common_gem_drift(list)
        declared = list.map { |i| (i.commons || {}).transform_keys(&:to_s) }
        shared_names = declared.map(&:keys).reduce(:&) || []

        shared_names.sort.filter_map do |gem_name|
          versions = declared.map { |d| d[gem_name] }.uniq
          next if versions.size <= 1

          { rule: :common_gem_version_drift, gem: gem_name, versions: versions,
            because: "#{gem_name} resolves to #{versions.size} different versions " \
                     "(#{versions.join(', ')}); Bundler will reinstall it per service and the " \
                     "common bundle layer stops being shared" }
        end
      end

      RULE = "Sharing requires BOTH halves: an identical, digest-pinned parent AND an " \
             "identically resolved common gem set. Either one alone silently yields no sharing."
    end
  end
end
