# frozen_string_literal: true

module Vv
  module CpcpHarness
    # What the *agent* may attempt in this session — a different question
    # from who may call the seam (the seam's auth answers that) and from
    # whether the payload means what the contract says (CPCP answers
    # that). Keeping the three apart is the point of design §10.
    #
    # When no rule matches, a PULL is allowed and a PUSH is asked about.
    class Permissions
      ACTIONS = %i[allow ask deny].freeze

      # A rule matches on the bare tool name, the operation IRI (exact or
      # with a trailing `*`), the face, or any combination.
      Rule = Struct.new(:name, :iri, :face, :action, keyword_init: true) do
        def matches?(tool)
          return false if name && name.to_s != tool.name
          return false if face && face.to_s != tool.face.to_s
          return false if iri && !iri_matches?(tool.iri)

          true
        end

        def iri_matches?(tool_iri)
          return false if tool_iri.nil?
          return tool_iri.start_with?(iri.to_s.delete_suffix("*")) if iri.to_s.end_with?("*")

          tool_iri == iri.to_s
        end
      end

      Decision = Struct.new(:action, :rule, keyword_init: true)

      attr_reader :rules

      def initialize(rules: [], approver: nil)
        @rules = Array(rules).map { |r| r.is_a?(Rule) ? r : Rule.new(**r.transform_keys(&:to_sym)) }
        @approver = approver
      end

      def decide(tool)
        rule = @rules.find { |r| r.matches?(tool) }
        return Decision.new(action: rule.action.to_sym, rule: rule) if rule

        Decision.new(action: default_action(tool), rule: nil)
      end

      # Ask the human. The prompt carries what the decision needs: the
      # operation IRI, the seam, the full params and the `operationId`.
      #
      # With no approver configured, `ask` is a decline — not a silent
      # allow. A decline is a decision the human made, which is why it is
      # `user_declined` and why its layer is `domain`.
      def approve(tool:, args:, operation_id: nil, context: nil)
        request = {
          tool: tool.name,
          iri: tool.iri,
          seam: tool.seam,
          face: tool.face,
          params: args,
          operation_id: operation_id,
          session_id: context&.session_id,
          agent: context&.agent,
          # Which road the call came in on, and how it is paid for. An
          # approver that defers to a client's own prompt needs both to
          # decide whether deferring is appropriate here.
          backend: context&.backend,
          auth_mode: context&.auth_mode
        }

        return { approved: false, because: "no approver is configured for this harness" } if @approver.nil?

        answer = @approver.call(request)
        case answer
        when true then { approved: true, by: context&.approved_by }
        when false, nil then { approved: false, because: "the human declined this operation" }
        when Hash
          normalized = answer.transform_keys(&:to_sym)
          {
            approved: normalized[:approved] == true,
            by: normalized[:by] || context&.approved_by,
            because: normalized[:because] || "the human declined this operation"
          }
        else { approved: true, by: answer.to_s }
        end
      end

      private

      def default_action(tool)
        return :ask if tool.push?
        return :allow if tool.pull?

        # An ungrounded native tool has no face to read, so the Doc 1
        # flag stands in: a read is allowed, anything else is asked about.
        tool.read_only? ? :allow : :ask
      end
    end
  end
end
