# frozen_string_literal: true

require "json"

module Vv
  module DependencyOrch
    module Adapters
      # Reads `.cpcp/deploy.json`. That file is THIS gem's declaration for
      # local_deploy and remote_deploy SHAs. It is not a pin index.
      #
      # vv-code-search already indexes FLOOR.json, Dockerfiles, lockfiles.
      # Re-parsing those here would be a second answer to "which lines carry a
      # pin". This adapter reads only the file whose kind is `cpcp-deploy`,
      # whose job is WHEN the SHA must be at a placement so the overlay runs.
      class Deploy
        RELPATH = File.join(".cpcp", "deploy.json")
        KIND = "cpcp-deploy"

        def available? = true

        # Envelope with :manifest, :edges, :resources, :names.
        #
        # Missing file is `not_indexed`, not a crash: inventory must stay
        # computable when a root has no deploy declaration yet.
        def load(root:)
          Envelope.never_raise do
            root = File.expand_path(root)
            path = File.join(root, RELPATH)
            unless File.file?(path)
              return Envelope.refuse(
                "not_indexed",
                "no #{RELPATH} under #{root}; compile/runtime protocol is .cpcp/package.json, " \
                "deploy SHAs live in #{RELPATH}"
              )
            end

            data = JSON.parse(File.read(path))
            checked = validate(data, root: root, path: path)
            return checked unless checked[:ok]

            repo = File.basename(root)
            edges = []
            resources = []
            names = Hash.new { |h, k| h[k] = [] }

            When::DEPLOY.each do |placement|
              slot = data[placement.to_s]
              next unless slot.is_a?(Hash)

              each_image(slot) do |image_key, image|
                digest = image["digest"]
                parsed = Identity.require!(digest)
                return parsed unless parsed[:ok]

                name = image["name"].to_s.strip
                names[digest] << name unless name.empty?

                index_digest = index_digest_of(image)
                kind = index_digest == false ? :local : :remote
                resources << Resource.new(
                  digest: digest,
                  kind: kind,
                  names: name.empty? ? [] : [name],
                  index_digest: index_digest,
                  meta: {
                    first_seen: "deploy",
                    when: placement,
                    image_key: image_key,
                    tag_for_humans: image["tag_for_humans"]
                  }.compact
                )

                edges << Edge.new(
                  kind: :declares,
                  from: deploy_node(repo, placement, "images", image_key),
                  to: digest,
                  where: {
                    repo: repo,
                    path: RELPATH,
                    pointer: "/#{placement}/images/#{image_key}/digest",
                    when: placement
                  },
                  because: image["because"] || "#{placement} declares #{image_key}"
                )
              end

              each_blob(slot) do |blob_digest, blob_meta|
                parsed = Identity.require!(blob_digest)
                return parsed unless parsed[:ok]

                resources << Resource.new(
                  digest: blob_digest,
                  kind: :remote,
                  names: Array(blob_meta["name"]),
                  index_digest: nil,
                  meta: { first_seen: "deploy", when: placement, store: blob_meta["store"] }
                )
                edges << Edge.new(
                  kind: :declares,
                  from: deploy_node(repo, placement, "blobs", blob_digest),
                  to: blob_digest,
                  where: {
                    repo: repo,
                    path: RELPATH,
                    pointer: "/#{placement}/blobs/required",
                    when: placement
                  },
                  because: blob_meta["because"] || "#{placement} requires blob #{Identity.short(blob_digest)}"
                )
              end
            end

            Envelope.ok(
              manifest: data,
              root: root,
              path: path,
              repo: repo,
              edges: edges,
              resources: resources,
              names: names.transform_values(&:uniq)
            )
          end
        end

        private

        def validate(data, root:, path:)
          unless data.is_a?(Hash)
            return Envelope.refuse("malformed_digest", "#{path} is not a JSON object")
          end
          unless data["kind"] == KIND
            return Envelope.refuse(
              "unsupported_kind",
              "#{path} kind is #{data['kind'].inspect}, want #{KIND}. " \
              ".cpcp/package.json is compile and runtime protocol; this file is deploy SHAs."
            )
          end
          unless data["version"].is_a?(Integer)
            return Envelope.refuse("malformed_digest", "#{path} version must be an integer")
          end

          has_slot = When::DEPLOY.any? { |k| data[k.to_s].is_a?(Hash) }
          unless has_slot
            return Envelope.refuse(
              "not_indexed",
              "#{path} has no local_deploy or remote_deploy object"
            )
          end

          Envelope.ok(root: root)
        end

        def each_image(slot)
          images = slot["images"]
          return unless images.is_a?(Hash)

          images.each do |key, image|
            next unless image.is_a?(Hash)

            yield key.to_s, image
          end
        end

        def each_blob(slot)
          blobs = slot["blobs"]
          return unless blobs.is_a?(Hash)

          required = blobs["required"]
          return unless required.is_a?(Array)

          store = blobs["store"]
          required.each do |entry|
            if entry.is_a?(String)
              yield entry, { "store" => store }
            elsif entry.is_a?(Hash) && entry["digest"]
              yield entry["digest"], entry.merge("store" => entry["store"] || store)
            end
          end
        end

        # Three-valued, same as Resource: String / false / nil.
        def index_digest_of(image)
          value = image.key?("index_digest") ? image["index_digest"] : nil
          return false if value == false
          return nil if value.nil? || value == ""

          parsed = Identity.parse(value.to_s)
          return nil unless parsed[:ok]

          parsed[:digest]
        end

        def deploy_node(repo, placement, family, key)
          "deploy:#{repo}/#{RELPATH}##{placement}/#{family}/#{key}"
        end
      end
    end
  end
end
