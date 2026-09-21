# frozen_string_literal: true

module Vv
  module DecisionObject
    # Never-raise boundary. Every public method returns
    # `{ ok: true, data:, ... }` or `{ ok: false, reason:, because: }`.
    #
    # A decision library that raises is a decision library that loses the
    # decision. A refusal is itself a decision outcome and belongs in the
    # trace, not in a backtrace.
    module Envelope
      module_function

      def ok(data: nil, **extra)
        { ok: true, data: data }.merge(extra.compact)
      end

      def refuse(reason, because, **extra)
        { ok: false, reason: reason.to_sym, because: because.to_s }.merge(extra.compact)
      end

      # Collapse a list of `problems` (strings) into one refusal.
      def refuse_all(reason, problems, **extra)
        list = Array(problems).map(&:to_s).reject(&:empty?)
        refuse(reason, list.join("; "), problems: list, **extra)
      end

      # Run `block`, converting any escaped exception into a refusal. The
      # gem's own code should not need this; adapters written by callers do.
      def guard(reason = :adapter_error)
        yield
      rescue StandardError => e
        refuse(reason, "#{e.class}: #{e.message}")
      end
    end
  end
end
