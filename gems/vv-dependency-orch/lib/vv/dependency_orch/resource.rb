# frozen_string_literal: true

module Vv
  module DependencyOrch
    # One identity, many placements.
    #
    # `sha256:8db4d39f` present in the local daemon, absent from GHCR and
    # running on a VPS is ONE resource in three placement states, not three
    # resources. Modelling it the other way is how "it works on my machine"
    # becomes an architecture.
    #
    # KIND IS AN IDENTITY SPACE, NOT A LOCATION. That is worth being precise
    # about, because `local` and `remote` read like places and are not:
    #
    #   :repo    identity is a 40-hex git commit
    #   :local   identity is a local image ID, and there is NO repo digest --
    #            the image was built here and never pushed
    #   :remote  identity is a registry digest (index or manifest)
    #
    # A pulled image is :remote WITH a local placement. A built image is :local
    # until it is pushed, at which point it acquires a registry digest and
    # becomes a different identity -- which is not a modelling wart, it is the
    # trap the plan names: "the image ID is not the registry digest unless the
    # image was pulled." Pretending one value serves both is the bug.
    class Resource
      KINDS = %i[repo local remote].freeze

      attr_reader :digest, :kind, :names, :platforms, :attestations, :placements, :meta

      # index_digest is THREE-VALUED and the three must survive to the output:
      #
      #   String  the registry index digest
      #   false   we know there is none -- a locally built image, never pushed
      #   nil     we have not determined it
      #
      # S1's acceptance is exactly this: a locally built image is represented as
      # `index_digest: false`, not as a missing digest. `false` and `nil` are the
      # difference between "there is none" and "we did not look", which is the
      # same distinction as absent-vs-not_indexed, one level down.
      attr_reader :index_digest

      def initialize(digest:, kind:, names: [], index_digest: nil, platforms: [],
                     attestations: [], meta: {})
        raise ArgumentError, "unknown resource kind #{kind.inspect}" unless KINDS.include?(kind)

        @digest = digest
        @kind = kind
        @names = Array(names).uniq
        @index_digest = index_digest
        @platforms = platforms
        @attestations = attestations
        @placements = {}
        @meta = meta
      end

      # Names are LABELS OBSERVED AT A TIME. They are carried so a human can read
      # the report, they are never the key, and nothing in this gem may look a
      # resource up by name without going through Graph#resolve, which refuses
      # an ambiguous one rather than picking.
      def observe_name(name)
        @names << name unless name.nil? || @names.include?(name)
        self
      end

      def observe(placement)
        existing = @placements[placement.key]
        @placements[placement.key] = placement if placement.supersedes?(existing)
        self
      end

      def placement(kind:, at:)
        @placements[[kind, at]]
      end

      # Every placement where a copy actually is. Note what this does NOT do:
      # treat unreachable as absent. A caller asking "can a consumer get this"
      # wants `reachable_placements`, and a caller asking "is it definitely
      # missing anywhere" wants `known_absent` -- and the gap between them, the
      # unreachable set, belongs to neither.
      def reachable_placements
        @placements.values.select(&:present?)
      end

      def known_absent
        @placements.values.select { |p| p.state == :absent }
      end

      def unreachable_placements
        @placements.values.select { |p| p.state == :unreachable }
      end

      def unlooked_placements
        @placements.values.select { |p| p.state == :not_indexed }
      end

      # Attestation manifests are NOT platforms. buildx adds one, it reports as
      # `unknown/unknown`, and a CLI that says "2 platforms" for a
      # single-platform image with an attestation has already lost the
      # operator's trust -- which is the whole reason this is a method with a
      # name and not an `.length` at three call sites.
      def platform_count = platforms.length

      def platform_names
        platforms.map { |p| [p[:os], p[:architecture], p[:variant]].compact.join("/") }
      end

      def multi_platform? = platform_count > 1

      # A locally built image, never pushed. The state the floor case was in,
      # and the one four consumers could not pull.
      def unpublished? = index_digest == false

      def to_h
        {
          digest: digest,
          kind: kind,
          names: names,
          # Written unconditionally, including when false. Dropping a false key
          # to keep the JSON tidy is how `index_digest: false` becomes
          # indistinguishable from "we did not look".
          index_digest: index_digest,
          platforms: platform_names,
          platform_count: platform_count,
          attestations: attestations.length,
          placements: placements.values.map(&:to_h)
        }.tap { |h| h[:meta] = meta unless meta.empty? }
      end
    end
  end
end
