# frozen_string_literal: true

require "time"

require_relative "dependency_orch/version"
require_relative "dependency_orch/envelope"
require_relative "dependency_orch/identity"
require_relative "dependency_orch/placement"
require_relative "dependency_orch/resource"
require_relative "dependency_orch/edge"
require_relative "dependency_orch/graph"
require_relative "dependency_orch/adapters/base"
require_relative "dependency_orch/adapters/local_daemon"
require_relative "dependency_orch/adapters/registry"
require_relative "dependency_orch/adapters/pins"
require_relative "dependency_orch/adapters/git_remote"
require_relative "dependency_orch/adapters/deploy"
require_relative "dependency_orch/when"
require_relative "dependency_orch/deploy"
require_relative "dependency_orch/inventory"
require_relative "dependency_orch/drift"
require_relative "dependency_orch/export"
require_relative "dependency_orch/render"

module Vv
  # One identity, many placements. See
  # magentic-stack/docs/architecture/plan_vv_dependency_orch.md.
  #
  # THIS FILE MUST NOT REQUIRE RAILS, AND NOTHING BELOW IT MAY EITHER.
  # magentic-stack is a Rails-at-root monorepo. This gem answers "the floor
  # moved -- who is now wrong?" by reading files (FLOOR.json, compose, pins).
  # A gate holds that rather than a convention: spec/gates_spec.rb.
  module DependencyOrch
    module_function

    # The three questions, as three entry points. Everything the rake tasks and
    # (later) the CLI do is one of these plus formatting.

    # Question 0, which the other three depend on: what is out there.
    def inventory(roots: [], local: true)
      inv = Inventory.new(roots: roots, local: local)
      graph = inv.build
      Envelope.ok(graph: graph, notes: inv.notes)
    end

    # Everything in the inventory, optionally one kind of it.
    def resource_list(graph, kind: nil, notes: [])
      unless kind.nil? || Resource::KINDS.include?(kind.to_sym)
        return Envelope.refuse("unsupported_kind",
                               "kind must be one of #{Resource::KINDS.join(', ')}, got #{kind.inspect}")
      end

      Envelope.ok(
        resources: graph.of_kind(kind).map(&:to_h).sort_by { |r| [r[:kind].to_s, r[:digest]] },
        notes: notes
      )
    end

    # Identity, placements and both edge sets for one resource.
    def show(graph, reference)
      found = graph.resolve(reference)
      return found unless found[:ok]

      resource = found[:resource]
      Envelope.ok(
        resource: resource.to_h,
        declares: graph.declares_of(resource.digest).map(&:to_h),
        references: graph.references_of(resource.digest).map(&:to_h)
      )
    end

    # Question 1 -- forward. What does this depend on, transitively.
    def deps(graph, reference, depth: 3)
      found = graph.resolve(reference)
      return found unless found[:ok]

      resource = found[:resource]
      Envelope.ok(
        digest: resource.digest,
        direction: :forward,
        edges: graph.forward(resource.digest, depth: depth).map { |h| h.merge(edge: h[:edge].to_h) }
      )
    end

    # Question 2 -- reverse. If this moves, what becomes wrong.
    #
    # The two sets come back APART. Merging them here would save four lines and
    # destroy the answer: the declaration is where you change the digest, the
    # references are what you re-check because it changed, and a caller handed
    # one list cannot tell which lines are which.
    def blast_radius(graph, reference)
      found = graph.resolve(reference)
      return found unless found[:ok]

      digest = found[:resource].digest
      Envelope.ok(
        digest: digest,
        direction: :reverse,
        declares: graph.declares_of(digest).map(&:to_h),
        references: graph.references_of(digest).map(&:to_h)
      )
    end

    # Question 3 -- drift.
    def drift(graph, notes: [])
      Drift.call(graph, notes: notes)
    end

    # Which adapters can actually answer. Not a convenience: it is what makes
    # every other command's silence interpretable. A clean drift report from a
    # host that was never reached is not a clean bill of health, and this is
    # where an operator finds that out before believing one.
    # `.cpcp/deploy.json` -- local_deploy / remote_deploy SHAs. Not protocol.
    def deploy(root:)
      Deploy.load(root: root)
    end

    def deploy_ready(root:, placement: :local_deploy)
      Deploy.ready(root: root, placement: placement)
    end

    def doctor(roots: [])
      daemon = Adapters::LocalDaemon.new
      registry = Adapters::Registry.new
      git = Adapters::GitRemote.new
      pins = Adapters::Pins.new
      deploy = Adapters::Deploy.new

      Envelope.ok(
        adapters: {
          local_daemon: { available: daemon.available?,
                          because: daemon.available? ? nil : "the Docker daemon did not answer" },
          registry: { available: registry.available?,
                      because: registry.available? ? nil : "docker buildx is not on PATH" },
          git: { available: git.available?,
                 because: git.available? ? nil : "git is not on PATH" },
          pins: { available: pins.available?,
                  because: pins.available? ? nil : Adapters::Pins.unavailable_envelope[:because] },
          deploy: { available: deploy.available?,
                    because: nil }
        },
        roots: Array(roots).map do |root|
          expanded = File.expand_path(root)
          { root: expanded, exists: Dir.exist?(expanded),
            shallow: (git.available? && Dir.exist?(expanded) ? git.shallow?(expanded) : nil) }
        end
      )
    end
  end
end
