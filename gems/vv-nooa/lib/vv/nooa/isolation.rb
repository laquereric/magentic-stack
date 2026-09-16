# frozen_string_literal: true

module Vv
  module Nooa
    # The security doctrine attached to "code as action": NOOA executes
    # LLM-generated code. AST validation + module deny-lists are DEFENSE-IN-DEPTH
    # (a linter for obvious mistakes), NOT a containment boundary. The real boundary
    # is an isolation layer (container / microVM / secure runtime).
    #
    # In magentic-stack that layer is the distroless MIND container plus Monty
    # (ADR 0071). This gem classifies controls; it does not sandbox anything.
    module Isolation
      module_function

      DEFENSE_IN_DEPTH     = %i[ast_validation module_deny_list resource_limits].freeze
      CONTAINMENT_BOUNDARY = %i[container micro_vm secure_runtime monty restricted_fs restricted_network restricted_credentials].freeze

      # never-raise classification of an isolation control.
      def classify(control)
        c = control.to_s.to_sym
        return { ok: true, control: c, kind: :defense_in_depth,     is_boundary: false } if DEFENSE_IN_DEPTH.include?(c)
        return { ok: true, control: c, kind: :containment_boundary, is_boundary: true }  if CONTAINMENT_BOUNDARY.include?(c)
        { ok: false, reason: :unknown_control, because: "unknown isolation control #{control.inspect}" }
      end

      RULE = "AST validation and deny-lists catch bugs; they are NOT the security boundary. " \
             "The isolation layer -- container / microVM / secure runtime with restricted fs, network, and credentials -- is the boundary. " \
             "In magentic-stack: the distroless MIND container is the OS boundary; Monty (ADR 0071) is the interpreter boundary inside it. " \
             "CPython is not a fallback."
    end
  end
end
