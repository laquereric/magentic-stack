# frozen_string_literal: true

require "json"

module Vv
  module DependencyOrch
    module Adapters
      # The local Docker daemon, read-only.
      #
      # Every command here is an inspect or a list. There is no pull, no build,
      # no tag, no rm, and the gate is that it stays that way -- a resource
      # manager that can restart production because a flag was in the wrong
      # place is a different product.
      #
      # THE TRAP THIS ADAPTER EXISTS TO GET RIGHT: the image ID is not the
      # registry digest. `Id` is the config digest, computed locally; only
      # `RepoDigests` carries a digest a registry would recognise, and a locally
      # built image has none until it is pushed. Reading `Id` and calling it a
      # digest is how a report claims an image is published when nothing outside
      # this laptop has ever seen it -- which is the floor case, exactly.
      class LocalDaemon < Base
        AT = "local"

        def available?
          return @available unless @available.nil?

          status, = run(%w[docker version --format {{.Server.Version}}], timeout: 5)
          @available = status == :ok
        end

        # Every image the daemon holds, as Resources with a local placement.
        #
        # Returns an envelope. On no daemon it refuses with `unreachable` rather
        # than returning an empty list, because an empty list from this method
        # would read as "you have no images".
        def inventory
          Envelope.never_raise do
            unless available?
              return Envelope.refuse(
                "unreachable",
                "the Docker daemon did not answer; this is not evidence that there are no local images"
              )
            end

            status, out, err = run(%w[docker image ls --no-trunc --format {{.ID}}])
            return Envelope.refuse("unreachable", "docker image ls failed: #{err.strip}") unless status == :ok

            ids = out.split("\n").map(&:strip).reject(&:empty?).uniq
            return Envelope.ok(resources: []) if ids.empty?

            status, out, err = run(["docker", "image", "inspect", *ids, "--format", "{{json .}}"])
            return Envelope.refuse("unreachable", "docker image inspect failed: #{err.strip}") unless status == :ok

            resources = out.each_line.filter_map do |line|
              line = line.strip
              next if line.empty?

              resource_from(JSON.parse(line))
            end

            Envelope.ok(resources: resources)
          end
        end

        # Is this digest in the local daemon? The one question that can produce
        # `absent` here, and only via round_trip.
        def placement_for(digest)
          round_trip(kind: :local_daemon, at: AT,
                     argv: ["docker", "image", "inspect", digest, "--format", "{{json .}}"]) do |status, out, err|
            if status == :ok
              info = JSON.parse(out.lines.first.to_s.strip)
              [:present, { image_id: info["Id"], platform: platform_of(info) }]
            elsif err.match?(/No such image|no such image/i)
              # A completed round trip that found nothing. THIS is evidence.
              [:absent, "the daemon answered and holds no image #{Identity.short(digest)}"]
            else
              # It failed for some other reason -- a broken socket mid-call, a
              # permissions error. We reached for it and did not get an answer
              # about the image, which is unreachable and not absent.
              [:unreachable, "docker image inspect failed: #{err.strip}"]
            end
          end
        end

        private

        def resource_from(info)
          repo_digests = Array(info["RepoDigests"])
          tags = Array(info["RepoTags"]).reject { |t| t == "<none>:<none>" }

          if repo_digests.empty?
            # Built here, never pushed. `index_digest: false` says "there is
            # none", which is a different claim from `nil` -- "we did not look"
            # -- and the two must not collapse. Four consumers pinning this
            # cannot pull it, and that fact starts here.
            resource = Resource.new(
              digest: info["Id"],
              kind: :local,
              index_digest: false,
              meta: { platform: platform_of(info), built_locally: true }
            )
          else
            # Pulled. The repo digest is a registry-recognised digest, but the
            # daemon CANNOT tell us whether it is an index digest or a
            # per-platform manifest digest -- it holds one platform and knows
            # only what it pulled by. So index_digest stays nil: not determined.
            # The registry adapter is the only thing entitled to settle that,
            # and guessing here would be the index/manifest confusion the plan
            # calls the most expensive mistake available.
            first = repo_digests.first
            resource = Resource.new(
              digest: first.split("@").last,
              kind: :remote,
              index_digest: nil,
              meta: { platform: platform_of(info), repo_digests: repo_digests }
            )
          end

          # Repository names WITHOUT their tags. The tag is recorded as a label
          # observed at a time, in meta, and never reaches `names` -- names is
          # what `resolve` matches against, and a tag matching there would make
          # a tag a key by the back door.
          tags.each { |t| resource.observe_name(t.rpartition(":").first) }
          resource.meta[:tags_observed] = tags unless tags.empty?

          resource.observe(
            Placement.present(
              kind: :local_daemon, at: AT,
              details: {
                image_id: info["Id"],
                platform: platform_of(info),
                size: info["Size"],
                created: info["Created"]
              }
            )
          )
          resource
        end

        def platform_of(info)
          [info["Os"], info["Architecture"], info["Variant"]].compact.reject(&:empty?).join("/")
        end
      end
    end
  end
end
