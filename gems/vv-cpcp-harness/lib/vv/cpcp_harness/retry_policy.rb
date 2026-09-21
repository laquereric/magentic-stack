# frozen_string_literal: true

require "time"

module Vv
  module CpcpHarness
    # When replay is safe, and only then (design §6.6).
    #
    # There is no `retryable` field on the wire, so the decision comes
    # from the status, the headers, the face and the presence of an
    # `operationId` — never from a reason string. A 503 is not a general
    # retry signal: without `Retry-After` there is no known window, and a
    # non-idempotent POST without a durable key is never retried.
    module RetryPolicy
      RETRY_AFTER_ATTEMPTS = 2   # 503 with a stated window
      TRANSPORT_ATTEMPTS   = 1   # no response at all
      MAX_WAIT = 30              # seconds; a longer window is left to the model

      Decision = Struct.new(:should_retry, :after, :because, keyword_init: true) do
        def retry?
          should_retry == true
        end
      end

      module_function

      # `attempt` counts retries already made for this tool call.
      def decide(face:, attempt: 0, http_status: nil, headers: {}, transport_error: nil, operation_id: nil)
        push = face.to_s == "push"
        # A PUSH can only be replayed under its own name. The harness
        # mints one for every PUSH, so this guard should never fire —
        # if it does, the safe answer is to stop.
        return no("a PUSH without an operationId is never retried") if push && operation_id.to_s.empty?

        if transport_error
          return no("no response, and one replay has already been made") if attempt >= TRANSPORT_ATTEMPTS

          return yes(0, "no response yet, so the call may never have landed")
        end

        return no("the method ran and decided") unless http_status.to_i == 503

        window = retry_after(headers)
        return no("503 without Retry-After is not a retry signal") if window.nil?
        return no("the stated window has been waited out twice") if attempt >= RETRY_AFTER_ATTEMPTS

        yes(window, "503 with a stated window and a safe replay")
      end

      def yes(after, because)
        Decision.new(should_retry: true, after: after, because: because)
      end

      def no(because)
        Decision.new(should_retry: false, after: nil, because: because)
      end

      # Delta-seconds or an HTTP-date. Anything else is no window at all.
      def retry_after(headers)
        raw = fetch_header(headers, "retry-after")
        return nil if raw.to_s.strip.empty?

        raw = raw.to_s.strip
        if raw.match?(/\A\d+\z/)
          clamp(raw.to_i)
        else
          begin
            clamp((Time.httpdate(raw) - Time.now).ceil)
          rescue ArgumentError
            nil
          end
        end
      end

      def fetch_header(headers, name)
        return nil unless headers.respond_to?(:each_pair)

        headers.each_pair { |k, v| return v if k.to_s.downcase == name }
        nil
      end

      def clamp(seconds)
        return 0 if seconds.negative?

        [seconds, MAX_WAIT].min
      end
    end
  end
end
