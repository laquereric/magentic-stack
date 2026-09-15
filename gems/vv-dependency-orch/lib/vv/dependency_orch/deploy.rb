# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Public surface for `.cpcp/deploy.json`.
    #
    # Inventory already loads the file as declares-edges. These helpers are the
    # questions `bin/docker-containers` asks without walking the whole graph:
    # what did this overlay declare, and are the local_deploy SHAs actually here.
    module Deploy
      module_function

      def load(root:)
        Adapters::Deploy.new.load(root: root)
      end

      # Are the images this overlay declared for `placement` present on the
      # local daemon? Pull/build is a write and lives in bin/docker-containers,
      # not here. This only reports.
      #
      # Unpublished floors (`index_digest: false`) that are not on the daemon
      # come back as `undeployable`, not `absent`: absence of a local image is
      # not evidence the digest is gone, and a clone that cannot pull must not
      # be told the floor does not exist.
      #
      # WHICH ADAPTER ANSWERS IS NOT A DETAIL. Placement::AUTHORITATIVE says
      # remote placement is the registry's to answer and local placement is the
      # daemon's. Asking the local daemon whether a GHCR digest is present
      # reports every published image as missing, because it is not there and
      # never was -- the machine was never the authority. That is the same
      # false absence that made a339861ae23e look like a bad pin when the pin
      # was correct.
      AUTHORITY = { local_deploy: :local_daemon, remote_deploy: :registry }.freeze

      def ready(root:, placement: :local_deploy, daemon: nil, registry: nil)
        loaded = load(root: root)
        return loaded unless loaded[:ok]

        unless When.deploy?(placement)
          return Envelope.refuse(
            "unsupported_kind",
            "placement must be local_deploy or remote_deploy, got #{placement.inspect}"
          )
        end

        slot = loaded[:manifest][placement.to_s]
        unless slot.is_a?(Hash)
          return Envelope.refuse(
            "not_indexed",
            "#{loaded[:path]} has no #{placement} object"
          )
        end

        images = slot["images"]
        unless images.is_a?(Hash) && !images.empty?
          return Envelope.refuse(
            "not_indexed",
            "#{loaded[:path]} #{placement} declares no images"
          )
        end

        authority = AUTHORITY[placement.to_sym]
        probe = placement.to_sym == :local_deploy ? (daemon || Adapters::LocalDaemon.new)
                                                  : (registry || Adapters::Registry.new)
        unless probe.available?
          return Envelope.refuse(
            "unreachable",
            "the #{authority} did not answer; this is not evidence the declared images are gone"
          )
        end

        missing = []
        present = []
        images.each do |key, image|
          next unless image.is_a?(Hash)

          digest = image["digest"].to_s
          parsed = Identity.require!(digest)
          return parsed unless parsed[:ok]

          placement_here = probe_for(probe, placement.to_sym, digest, image)

          # A tag is never identity, but a locally BUILT image has no registry
          # digest to be found under, so the tag is the only handle the daemon
          # has. That fallback is the local daemon's alone: a tag at a registry
          # resolves to whatever was last pushed, which is a different question.
          tag = image["tag_for_humans"].to_s
          tagged = if placement.to_sym == :local_deploy && !tag.empty?
                     probe.placement_for(tag)
                   end

          if placement_here.state == :unreachable && (tagged.nil? || tagged.state == :unreachable)
            return Envelope.refuse("unreachable", placement_here.because)
          end

          here = placement_here.present? || (tagged && tagged.present?)
          if here
            present << { key: key, digest: digest, name: image["name"] }
            next
          end

          where = placement.to_sym == :local_deploy ? "this daemon" : "the registry"
          missing << {
            key: key,
            digest: digest,
            name: image["name"],
            index_digest: image.key?("index_digest") ? image["index_digest"] : nil,
            tag_for_humans: image["tag_for_humans"],
            because: unpublished?(image) ?
              "#{key} is unpublished (index_digest: false) and not on #{where}" :
              "#{key} #{Identity.short(digest)} is not on #{where}"
          }
        end

        if missing.empty?
          return Envelope.ok(placement: placement, present: present, missing: [])
        end

        Envelope.refuse(
          "undeployable",
          missing.map { |m| m[:because] }.join("; ")
        ).merge(placement: placement, present: present, missing: missing)
      end

      # The registry needs to be told WHICH registry. A name with no host is a
      # Docker Hub name; that default belongs here rather than in the adapter,
      # which should not be guessing what an unqualified name meant.
      def probe_for(probe, placement, digest, image)
        return probe.placement_for(digest) if placement == :local_deploy

        name = image["name"].to_s
        head = name.split("/").first.to_s
        at = head.include?(".") || head.include?(":") ? head : "docker.io"
        probe.placement_for(digest, at: at, repository: name)
      end

      def unpublished?(image)
        image.is_a?(Hash) && image["index_digest"] == false
      end
    end
  end
end
