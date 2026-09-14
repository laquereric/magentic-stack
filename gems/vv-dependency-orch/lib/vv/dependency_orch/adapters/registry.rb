# frozen_string_literal: true

require "json"
require "digest"

module Vv
  module DependencyOrch
    module Adapters
      # A remote registry, via `docker buildx imagetools inspect`.
      #
      # This adapter exists to get ONE distinction right, and the plan calls
      # confusing it "the most expensive mistake here": a multi-platform tag
      # resolves to an INDEX digest, the index holds one MANIFEST digest per
      # platform, and those are different digests for the same pull.
      #
      # On top of that, buildx adds an ATTESTATION manifest that reports as
      # `unknown/unknown` and reads like a second platform to anyone who does
      # not know. Measured against docker.io/library/hello-world on 2026-09-13:
      # 19 manifests in the index, of which 8 are attestations. A tool that
      # reports 19 platforms, or even 12, is lying in a way an operator cannot
      # catch.
      class Registry < Base
        # Two ways to spot an attestation, and both are checked because they
        # come from different layers. The annotation is buildx's own marker; the
        # unknown/unknown platform is what the OCI index shows to a reader that
        # does not know the annotation. Either one is sufficient, and requiring
        # both would miss a registry that drops annotations on copy.
        ATTESTATION_ANNOTATION = "vnd.docker.reference.type"
        ATTESTATION_VALUE = "attestation-manifest"

        INDEX_MEDIA_TYPES = [
          "application/vnd.oci.image.index.v1+json",
          "application/vnd.docker.distribution.manifest.list.v2+json"
        ].freeze

        # Registry errors that mean "we asked and it is not there". Everything
        # else -- 401, 403, DNS, TLS, timeouts -- is unreachable, because an
        # image you are not allowed to see is not an image that is gone.
        ABSENT_PATTERNS = /not found|manifest unknown|MANIFEST_UNKNOWN|no such manifest|repository name not known/i

        def available?
          return @available unless @available.nil?

          status, = run(%w[docker buildx version], timeout: 5)
          @available = status == :ok
        end

        # Resolves a reference at a registry into index/platform/attestation
        # facts. `reference` here MAY be a tag -- this is the one operation
        # whose entire job is to turn a label into a digest. It returns the
        # digest; it does not store the tag as identity.
        def resolve(reference)
          Envelope.never_raise do
            unless available?
              return Envelope.refuse("adapter_unavailable", "docker buildx is not available here")
            end

            status, out, err = run(["docker", "buildx", "imagetools", "inspect", "--raw", reference])

            case status
            when :timeout
              return Envelope.refuse("unreachable", "timed out resolving #{reference}; not evidence of absence")
            when :missing
              return Envelope.refuse("adapter_unavailable", err.strip)
            when :failed
              text = err.to_s
              if text.match?(ABSENT_PATTERNS)
                return Envelope.ok(found: false, because: "the registry answered: no such manifest for #{reference}")
              end

              return Envelope.refuse("unreachable", "imagetools inspect failed: #{text.strip}")
            end

            Envelope.ok(found: true, **parse_raw(out))
          end
        end

        # Is this digest at this registry?
        def placement_for(digest, at:, repository:)
          reference = "#{repository}@#{digest}"
          round_trip(kind: :registry, at: at,
                     argv: ["docker", "buildx", "imagetools", "inspect", "--raw", reference]) do |status, out, err|
            if status == :ok
              [:present, { repository: repository }.merge(parse_raw(out).slice(:platforms, :attestations))]
            elsif err.to_s.match?(ABSENT_PATTERNS)
              [:absent, "#{at} answered: no manifest #{Identity.short(digest)} in #{repository}"]
            else
              # 401 lands here on purpose. "You are not authorised to see this"
              # is not "this does not exist", and reporting the second would
              # send someone to republish an image that is already there.
              [:unreachable, "imagetools inspect failed at #{at}: #{err.to_s.strip}"]
            end
          end
        end

        private

        # The digest of a manifest IS the sha256 of its bytes. That is the
        # definition, not a shortcut, and it saves a second round trip -- but it
        # was verified rather than assumed: measured against hello-world on
        # 2026-09-13, sha256 of the --raw bytes equals the Digest that
        # `imagetools inspect` reports. It only holds if the bytes are not
        # re-encoded on the way here, which is why Base.run buffers in BINARY.
        def parse_raw(raw)
          bytes = raw.to_s.dup.force_encoding(Encoding::BINARY)
          digest = "sha256:#{::Digest::SHA256.hexdigest(bytes)}"
          doc = JSON.parse(bytes.force_encoding(Encoding::UTF_8))

          unless INDEX_MEDIA_TYPES.include?(doc["mediaType"])
            # A single manifest, no index. `index_digest: false` is the honest
            # answer -- there is none -- and it is the same shape a locally
            # built image gets, for the same reason: false means none, nil means
            # nobody looked.
            return {
              digest: digest,
              index_digest: false,
              platforms: [],
              attestations: [],
              media_type: doc["mediaType"]
            }
          end

          manifests = Array(doc["manifests"])
          attestations, platforms = manifests.partition { |m| attestation?(m) }

          {
            digest: digest,
            index_digest: digest,
            platforms: platforms.map { |m| platform_entry(m) },
            attestations: attestations.map { |m| { digest: m["digest"], of: m.dig("annotations", "vnd.docker.reference.digest") } },
            media_type: doc["mediaType"]
          }
        end

        def attestation?(manifest)
          return true if manifest.dig("annotations", ATTESTATION_ANNOTATION) == ATTESTATION_VALUE

          platform = manifest["platform"] || {}
          platform["os"] == "unknown" && platform["architecture"] == "unknown"
        end

        def platform_entry(manifest)
          platform = manifest["platform"] || {}
          {
            os: platform["os"],
            architecture: platform["architecture"],
            variant: platform["variant"],
            digest: manifest["digest"]
          }
        end
      end
    end
  end
end
