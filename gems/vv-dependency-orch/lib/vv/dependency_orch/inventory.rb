# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Assembles a Graph from whatever sources are reachable.
    #
    # The single rule: **the graph must be computable with zero reachable
    # placements.** A missing daemon, a missing index gem, no network -- each
    # subtracts facts and none of them fails the build. Otherwise `drift` could
    # not report `unreachable`; it would just crash, and a tool that dies when
    # the network is down cannot be the tool that tells you the network is down.
    #
    # So every source here is wrapped, every failure becomes a `note`, and the
    # notes ride out with the graph. A caller that ignores them is looking at a
    # partial world it was told about.
    class Inventory
      attr_reader :notes

      def initialize(roots: [], local: true, pins: nil, daemon: nil, git: nil, registry: nil, deploy: nil)
        @roots = Array(roots).map { |r| File.expand_path(r) }
        @local = local
        @pins = pins || Adapters::Pins.new
        @deploy = deploy || Adapters::Deploy.new
        @daemon = daemon || Adapters::LocalDaemon.new
        # Repo-kind resources had NO placement at all until this existed --
        # not unreachable, not never-looked, nothing -- so drift could only
        # report "no placement gave a completed answer: 0 unreachable, 0 never
        # checked", which reads as a coverage gap and was one.
        @git = git || Adapters::GitRemote.new
        # The registry is the only thing that can answer whether a REMOTE digest
        # exists. Without it a clean drift report means "nothing local
        # contradicts the declarations", which is a much weaker claim than it
        # reads as.
        @registry = registry || Adapters::Registry.new
        @notes = []
      end

      def build
        graph = Graph.new
        local_digests = load_local(graph)
        load_pins(graph, local_digests)
        load_deploy(graph, local_digests)
        graph
      end

      # Notes are the difference between "nothing was found" and "nothing was
      # looked at". Every source that could not run says so here, in the same
      # closed vocabulary the envelopes use.
      def note(reason, because)
        @notes << { reason: reason, because: because }
        nil
      end

      private

      # Returns the set of digests the daemon holds, or nil if the daemon never
      # gave a complete answer.
      #
      # THAT NIL IS LOAD-BEARING. A complete `docker image ls` is a round trip
      # that covers the whole placement at once: any digest not in the returned
      # set is genuinely `absent` locally, and we are entitled to say so. A
      # PARTIAL or failed listing entitles us to nothing, and the difference
      # between the two is this nil.
      def load_local(graph)
        unless @local
          note("not_indexed", "the local daemon was not consulted (local: false)")
          return nil
        end

        result = @daemon.inventory
        unless result[:ok]
          note(result[:reason], result[:because])
          return nil
        end

        digests = {}
        result[:resources].each do |resource|
          graph.add_resource(resource)
          digests[resource.digest] = true
          resource.placements.each_value do |placement|
            graph.add_edge(
              Edge.new(kind: :placed_at, from: resource.digest, to: "placement:#{placement.at}",
                       where: { at: placement.at }, because: placement.state.to_s)
            )
          end
        end
        digests
      end

      def load_pins(graph, local_digests)
        if @roots.empty?
          note("not_indexed", "no repository root was given, so no declarations were read")
          return
        end

        unless @pins.available?
          note("not_indexed", Adapters::Pins.unavailable_envelope[:because])
          return
        end

        @roots.each { |root| load_root(graph, root, local_digests) }
      end

      # Deploy declarations are this gem's file, not the pin index. A root
      # without `.cpcp/deploy.json` is not_indexed for deploy and still has
      # whatever pins it has.
      def load_deploy(graph, local_digests)
        if @roots.empty?
          note("not_indexed", "no repository root was given, so no deploy declarations were read")
          return
        end

        @roots.each { |root| load_deploy_root(graph, root, local_digests) }
      end

      def load_deploy_root(graph, root, local_digests)
        loaded = @deploy.load(root: root)
        unless loaded[:ok]
          note(loaded[:reason], loaded[:because])
          return
        end

        Array(loaded[:edges]).each { |edge| graph.add_edge(edge) }
        Array(loaded[:resources]).each do |resource|
          existing = graph.add_resource(resource)
          next if existing.kind == :repo

          existing.observe(local_placement_for(existing.digest, local_digests))
          # Unpublished means there is no registry digest. Asking docker.io
          # about a local name would manufacture a false absence.
          next if existing.unpublished?

          registry_placements_for(existing).each { |pl| existing.observe(pl) }
        end
      end

      def load_root(graph, root, local_digests)
        indexed = @pins.index_for(root: root)
        unless indexed[:ok]
          note(indexed[:reason], indexed[:because])
          return
        end

        repo = indexed[:repo]
        edged = @pins.edges(index: indexed[:index], repo: repo)
        unless edged[:ok]
          note(edged[:reason], edged[:because])
          return
        end

        # Asked of the index, not read off disk: .gitmodules is a pin source
        # and this gem does not parse those.
        submodules = @pins.submodule_paths(index: indexed[:index])
        declared_names = edged[:names] || {}

        edged[:edges].each do |edge|
          graph.add_edge(edge)
          ensure_pin_node(graph, edge.to, local_digests, root: root, submodules: submodules,
                                                         names: declared_names[edge.to] || [])
        end
      end

      # A digest named in a file but not held anywhere we have looked still
      # deserves a node -- that is the whole point. It arrives with its local
      # placement already decided, because the daemon listing (if it completed)
      # is evidence about every digest it did not contain.
      def ensure_pin_node(graph, node, local_digests, root: nil, submodules: [], names: [])
        return unless Identity.identity?(node)
        return if graph[node]

        parsed = Identity.parse(node)
        kind = parsed[:kind] == :git ? :repo : :remote
        resource = Resource.new(digest: node, kind: kind, index_digest: nil, names: names,
                                meta: { first_seen: "declaration" })

        if kind == :remote
          resource.observe(local_placement_for(node, local_digests))
          registry_placements_for(resource).each { |pl| resource.observe(pl) }
        else
          # Repo-kind resources had NO placement at all before this -- not
          # unreachable, not never-looked, nothing -- so drift could only say
          # "0 unreachable, 0 never checked", which reads as coverage and was a
          # gap.
          resource.observe(
            @git.placement_across(parsed[:digest] || node,
                                  roots: root ? [root] : @roots, submodules: submodules)
          )
        end

        graph.add_resource(resource)
      end

      # ONE registry placement per repository the declarations name.
      #
      # A digest alone cannot be resolved: `imagetools inspect` takes
      # repository@digest. So this asks only about repositories a declaration
      # actually named, and says never_looked -- not absent -- when there is no
      # name to ask with. Inventing a repository would manufacture exactly the
      # false absence the rest of this gem refuses.
      def registry_placements_for(resource)
        repositories = resource.names.filter_map { |n| repository_of(n) }.uniq
        if repositories.empty?
          return [Placement.never_looked(
            kind: :registry, at: "registry",
            because: "no declaration gave this digest a repository, and a bare digest is not " \
                     "something a registry can be asked about"
          )]
        end
        return [] unless @registry.available?

        repositories.map do |repo|
          @registry.placement_for(resource.digest, at: registry_host(repo), repository: repo)
        end
      end

      # `rust:1.96.1-bookworm` -> `rust`. The tag is dropped because it is not
      # identity and the digest already is; keeping it would ask the registry a
      # question with two answers in it.
      def repository_of(name)
        text = name.to_s.strip
        return nil if text.empty?

        text = text.split("@").first.to_s
        # A tag is the segment after the LAST colon, but only if that segment
        # has no slash -- otherwise it is a port, as in localhost:5000/x.
        head, sep, tail = text.rpartition(":")
        text = head if sep == ":" && !tail.include?("/") && !head.empty?
        text.empty? ? nil : text
      end

      def registry_host(repository)
        first = repository.split("/").first.to_s
        first.include?(".") || first.include?(":") ? first : "docker.io"
      end

      def local_placement_for(digest, local_digests)
        if local_digests.nil?
          Placement.never_looked(
            kind: :local_daemon, at: Adapters::LocalDaemon::AT,
            because: "the daemon listing did not complete, so it says nothing about this digest"
          )
        elsif local_digests.key?(digest)
          Placement.present(kind: :local_daemon, at: Adapters::LocalDaemon::AT)
        else
          Placement.absent(
            kind: :local_daemon, at: Adapters::LocalDaemon::AT,
            because: "the daemon listed every image it holds and this digest was not among them"
          )
        end
      end
    end
  end
end
