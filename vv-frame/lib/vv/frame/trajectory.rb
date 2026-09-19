# frozen_string_literal: true

module Vv
  module Frame
    # A use-case slice, Perch-shaped, supplied by the caller.
    #
    # This gem holds no slice store and mints no receiver. A receiver it cannot
    # be handed is a receiver it cannot name -- the same shape as the rule it
    # enforces below.
    class Slice
      # T1: the receiver predates the cut. It may not be anything the cut
      # created. Closed list; a kind outside it is unknown, not permitted.
      RECEIVER_KINDS = %w[developer stakeholder operator customer].freeze
      RECEIVER_FORBIDDEN = %w[building_team agent tooling gate sibling_slice harness].freeze

      attr_reader :key, :aim, :receiver, :receiver_kind, :outward_signal, :for_slice

      def initialize(key:, aim:, receiver:, receiver_kind:, outward_signal: nil, for_slice: nil)
        @key = key.to_s
        @aim = aim.to_s
        @receiver = receiver.to_s
        @receiver_kind = receiver_kind.to_s
        @outward_signal = outward_signal
        @for_slice = for_slice
      end

      # Findings, not a verdict. Each names the thing rather than the mechanism.
      def findings
        f = []
        f << finding(:aim_absent, "the slice states no aim") if aim.empty?
        if RECEIVER_FORBIDDEN.include?(receiver_kind)
          f << finding(:receiver_did_not_predate_the_cut,
                       "receiver kind #{receiver_kind} is something the cut created",
                       "name a receiver who existed before this work did")
        elsif !RECEIVER_KINDS.include?(receiver_kind)
          f << finding(:receiver_kind_unknown, "receiver kind #{receiver_kind} is outside the closed set")
        end
        f << finding(:signal_not_instrumented, "no outward signal reaches a source") if outward_signal.nil?
        f
      end

      # Three closed states. A pending signal is not a failing one, and a slice
      # with no signal yet is not a slice that failed.
      def signal_state
        return :not_instrumented if outward_signal.nil?
        return :reporting if outward_signal[:matured_at]

        :pending
      end

      def finding(test, text, resolution = nil)
        { test: test, finding: text, suggested_resolution: resolution }.compact
      end
    end

    # The object four parties share: development-time agents, production-time
    # agents, developers, users.
    #
    # Aim and receiver from the slice; constraints and gates from the decision
    # tree; placement from the frame. Loadable in one pass, re-loadable after a
    # reset -- which is the whole specification.
    class Trajectory
      PARTIES = %i[development_agent production_agent developer user].freeze

      attr_reader :party, :slice, :decisions, :path, :bundle

      def initialize(bundle:, path:, slice:, decisions:, party:)
        @bundle = bundle
        @path = path.to_s
        @slice = slice
        @decisions = decisions
        @party = party
      end

      def self.for(bundle:, path:, slice:, party: :development_agent)
        return refuse(:unknown_party, party.to_s) unless PARTIES.include?(party.to_sym)
        return refuse(:slice_absent, "a trajectory without an aim orients nothing") if slice.nil?

        chain = receiver_chain(slice)
        return chain unless chain[:ok]

        { ok: true,
          trajectory: new(bundle: bundle, path: path, slice: slice,
                          decisions: bundle.for_path(path), party: party.to_sym) }
      end

      # Walk receiver -> receiver's receiver, and refuse a cycle by the thing it
      # means rather than by the mechanism that found it.
      def self.receiver_chain(slice)
        seen = []
        node = slice
        while node
          return refuse(:slices_are_one_whole, seen.join(" -> ")) if seen.include?(node.key)

          seen << node.key
          node = node.for_slice
        end
        { ok: true, chain: seen }
      end

      def self.refuse(reason, because) = { ok: false, reason: reason, because: because }

      def chain = self.class.receiver_chain(slice).fetch(:chain, [])
      def constraints = decisions
      def gates = decisions.flat_map(&:gates).uniq.sort
      def unenforced = decisions.select(&:unenforced?)

      # Does the chain terminate outside the system? If every receiver in it is
      # something the work created, the aim never leaves the harness.
      def terminates_outside?
        node = slice
        node = node.for_slice while node.for_slice
        Slice::RECEIVER_KINDS.include?(node.receiver_kind)
      end

      def findings
        f = slice.findings.map { |x| x.merge(source: :slice) }
        f += decisions.flat_map do |d|
          d.placement.findings.map { |x| x.merge(source: :decision, adr_id: d.id) }
        end
        unless terminates_outside?
          f << { source: :trajectory, test: :aim_ends_inside_the_system,
                 finding: "no receiver in the chain is outside the work",
                 suggested_resolution: "name a stakeholder the cut did not create" }
        end
        f
      end

      # The trajectory as text a reader with no memory can pick up. Verbatim
      # fields only; nothing here is rewritten or condensed.
      def to_markdown
        out = +"# Trajectory — #{slice.key}\n\n"
        out << "* **Party** — #{party}\n"
        out << "* **Path** — `#{path}`\n" unless path.empty?
        out << "* **Receiver** — #{slice.receiver} (#{slice.receiver_kind})\n"
        out << "* **Chain** — #{chain.join(' → ')}\n" if chain.size > 1
        out << "* **Aim** — #{slice.aim}\n"
        out << "* **Outward signal** — #{slice.signal_state}\n\n"
        unless decisions.empty?
          out << "## Constraints — decisions governing this path\n\n"
          decisions.each do |d|
            p = d.placement
            out << "* **ADR #{d.id} — #{d.title}** · #{p.layer} · rung #{p.rung} · #{p.instrument}\n"
          end
          out << "\n"
        end
        unless gates.empty?
          out << "## Gates — what will catch me\n\n"
          gates.each { |g| out << "* `#{g}`\n" }
          out << "\n"
        end
        unless findings.empty?
          out << "## Findings\n\n"
          findings.each { |x| out << "* #{x[:test]} — #{x[:finding]}\n" }
          out << "\n"
        end
        out
      end

      def estimated_tokens = (to_markdown.length / Concept::CHARS_PER_TOKEN.to_f).ceil
    end
  end
end
