# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Where a declared digest disagrees with the placement that is actually
    # there.
    #
    # This is the question that catches the floor case: *declared* arm64 local,
    # *placed* nowhere a consumer can reach. Nothing in magentic-stack's eight
    # gates can see it, because each of them checks one kind in isolation and
    # this is a fact about an edge.
    #
    # THE DISCIPLINE HERE IS RESTRAINT. A drift report is read as a work list,
    # so a finding that turns out to be "we could not check" costs the operator
    # a trip and costs the tool its credibility. Findings therefore require
    # EVIDENCE -- a completed round trip that said no -- and everything else
    # comes back under `unknown`, which is a separate list with a separate
    # heading and is not a finding.
    module Drift
      FINDINGS = {
        unpublished_but_referenced:
          "a locally built image with no repo digest is named by lines that cannot pull it",
        declared_but_absent:
          "every placement we reached says this digest is not there, and lines still name it",
        no_reachable_placement:
          "the digest exists somewhere we know of, but nowhere a consumer could reach"
      }.freeze

      module_function

      # Returns an envelope: findings, unknowns, and what was examined.
      def call(graph, notes: [])
        Envelope.never_raise do
          findings = []
          unknown = []
          examined = 0

          graph.resources.each_value do |resource|
            consumers = consumers_of(graph, resource.digest)
            # A resource nobody names cannot drift. An unreferenced image on a
            # laptop is not a problem, it is a Tuesday.
            next if consumers.empty?

            examined += 1

            if resource.unpublished?
              findings << finding(:unpublished_but_referenced, resource, consumers,
                                  "index_digest is false: this image was built locally and never " \
                                  "pushed, so nothing outside this daemon can pull it")
              next
            end

            reachable = resource.reachable_placements
            next unless reachable.empty?

            unreachable = resource.unreachable_placements
            unlooked = resource.unlooked_placements
            absent = resource.known_absent

            # ONLY AN AUTHORITY'S "no" IS EVIDENCE. The local daemon answering
            # absent for a REMOTE image means it was never pulled here, not that
            # the digest is gone -- see Placement::AUTHORITATIVE. Counting that
            # as evidence is how a live base image gets reported as missing and
            # someone goes looking for a pin to change.
            hearsay = absent.reject { |pl| pl.authoritative_for?(resource.kind) }
            absent = absent.select { |pl| pl.authoritative_for?(resource.kind) }

            if absent.any? && unreachable.empty? && unlooked.empty?
              # Every placement gave a completed answer and all of them said no.
              findings << finding(:declared_but_absent, resource, consumers,
                                  "checked #{absent.length} placement(s), all answered absent: " \
                                  "#{absent.map(&:at).join(', ')}")
            elsif absent.any?
              # Some evidence of absence, but not everywhere. Still a finding --
              # the digest is provably missing from somewhere a consumer looks --
              # and the because carries what was not checked so nobody reads it
              # as a complete picture.
              findings << finding(:no_reachable_placement, resource, consumers,
                                  "absent at #{absent.map(&:at).join(', ')}; " \
                                  "#{unreachable.length} unreachable, #{unlooked.length} never checked")
            else
              # No evidence either way. THIS IS NOT A FINDING, and turning it
              # into one is the exact mistake the plan spends a table on.
              unknown << {
                digest: resource.digest,
                names: resource.names,
                consumers: consumers.length,
                because: (hearsay.any? ?
                  "no AUTHORITY gave a completed answer. #{hearsay.length} placement(s) said " \
                  "absent (#{hearsay.map(&:at).join(', ')}) but none of them can answer whether " \
                  "a #{resource.kind} digest exists -- that is not-here, not gone. " :
                  "no placement gave a completed answer: ") + "" \
                         "#{unreachable.length} unreachable, #{unlooked.length} never checked"
              }
            end
          end

          Envelope.ok(
            findings: findings,
            unknown: unknown,
            examined: examined,
            notes: notes
          )
        end
      end

      # The consumers are the point. "One finding" is a report; "one finding,
      # and here are the four lines in three repos that name it" is a work list,
      # and the plan's S4 acceptance asks for the consumer to be NAMED.
      #
      # `declares` and `references` are collected together here and kept apart
      # in the output. That is not a contradiction of the disjointness rule --
      # it is what the rule is for: the declaration is where you change the
      # digest, the references are what you re-check because it changed, and a
      # maintainer needs to see which is which.
      def consumers_of(graph, digest)
        (graph.declares_of(digest) + graph.references_of(digest)).map do |edge|
          {
            kind: edge.kind,
            repo: edge.where[:repo],
            path: edge.where[:path],
            line: edge.where[:line],
            source: edge.because
          }
        end
      end

      def finding(kind, resource, consumers, because)
        declares, references = consumers.partition { |c| c[:kind] == :declares }
        {
          finding: kind,
          means: FINDINGS[kind],
          digest: resource.digest,
          short: Identity.short(resource.digest),
          names: resource.names,
          platform: resource.meta[:platform],
          because: because,
          declared_at: declares,
          referenced_by: references
        }
      end
    end
  end
end
