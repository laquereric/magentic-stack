# frozen_string_literal: true

require "time"

module Vv
  module CpcpHarness
    # A conformant CPCP caller for one seam (design §6.4).
    #
    # Check the pin, build params, carry the `operationId`, send, read
    # *both* signals, retry only where the contract says replay is safe,
    # and hand back an envelope. It never raises: a dropped connection and
    # a grounding refusal take the same shape, because to the model they
    # are the same kind of news.
    class Client
      DEFAULT_PIN_TTL = 300 # seconds

      DURABILITY_WARNING =
        "The seam reports its idempotency store is not durable, so retrying with the same " \
        "operationId may not be deduplicated. The effect proceeded."

      attr_reader :seam, :cid, :transport

      def initialize(seam:, transport:, cid:, contract_version: nil, pin_ttl: DEFAULT_PIN_TTL,
                     clock: nil, sleeper: nil)
        @seam = seam.to_s
        @transport = transport
        @cid = cid
        @contract_version = contract_version
        @pin_ttl = pin_ttl
        @clock = clock || -> { Time.now }
        @sleeper = sleeper || ->(seconds) { sleep(seconds) }
        @pin_checked_at = nil
        @pin_refusal = nil
        @warnings = []
      end

      # One tool call. `face` decides the retry rules and whether an
      # `operationId` travels; the caller (Registry) has already minted
      # one for every PUSH.
      def call(method:, face:, params: {}, operation_id: nil, rpc_id: nil, iri: nil)
        pin = check_pin
        return decorate(pin, method, face, operation_id, iri) if pin

        built = build_params(params)
        return decorate(built, method, face, operation_id, iri) unless built[:ok]

        envelope = send_with_retries(
          method: method, face: face, params: built[:result],
          operation_id: operation_id, rpc_id: rpc_id
        )
        decorate(envelope, method, face, operation_id, iri)
      end

      # On first use per session, and then on a short TTL: does the live
      # CID still describe the seam the snapshot pinned? Returns nil when
      # the pin holds and a `contract_superseded` refusal when it does not.
      #
      # A pin check that cannot reach the seam is not a supersession. It
      # is recorded as a warning and retried on the next call; the call
      # itself will fail on its own if the seam is really gone.
      def check_pin(force: false)
        return @pin_refusal if @pin_refusal
        return nil unless force || pin_stale?

        res = @transport.cid
        unless res.is_a?(Hash) && res[:exchanged]
          @warnings << "the live CID could not be fetched: #{Envelope.text(res[:because])}"
          return nil
        end

        live = Cid.from(res[:body])
        unless live[:ok]
          @warnings << "the live CID could not be read: #{Envelope.text(live[:because])}"
          return nil
        end

        problem = @cid.superseded_by(live[:result], contract_version: @contract_version)
        @pin_checked_at = @clock.call
        return nil if problem.nil?

        @pin_refusal = Envelope.refuse(:contract_superseded, problem, seam: @seam)
      end

      # Warnings collected since the last call — pin checks that could not
      # run, durability notes the seam reported.
      def take_warnings
        taken = @warnings
        @warnings = []
        taken
      end

      private

      def pin_stale?
        return true if @pin_checked_at.nil?

        (@clock.call - @pin_checked_at) >= @pin_ttl
      end

      # Params are always an object, and the bridge never coerces anything
      # else to `{}`. The CID's `@context` is injected here so the model
      # never has to write JSON-LD.
      def build_params(params)
        unless params.is_a?(Hash)
          return Envelope.refuse(:harness_input_rejected,
                                 "params must be an object, got #{params.class}")
        end

        wire = params.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
        wire.delete("operationId")
        wire.delete("operation_id")
        wire["@context"] = @cid.context if @cid.context && !wire.key?("@context")
        Envelope.ok(result: wire)
      end

      def send_with_retries(method:, face:, params:, operation_id:, rpc_id:)
        attempt = 0
        loop do
          res = @transport.rpc(method: method, params: params,
                               operation_id: operation_id, rpc_id: rpc_id)

          if res.is_a?(Hash) && res[:exchanged]
            decision = RetryPolicy.decide(face: face, attempt: attempt, http_status: res[:http_status],
                                          headers: res[:headers], operation_id: operation_id)
            if decision.retry?
              @sleeper.call(decision.after.to_i)
              attempt += 1
              next
            end

            return read_exchange(res)
          end

          decision = RetryPolicy.decide(face: face, attempt: attempt, transport_error: true,
                                        operation_id: operation_id)
          if decision.retry?
            attempt += 1
            next
          end

          # A transport refusal already has the binding's reason on it.
          return res
        end
      end

      def read_exchange(res)
        if res[:parse_error]
          return Envelope.refuse(:seam_body_unparseable, res[:parse_error],
                                 http_status: res[:http_status])
        end

        if res[:body].nil?
          return Envelope.refuse(:seam_body_unparseable, "the seam answered with an empty body",
                                 http_status: res[:http_status])
        end

        envelope = Envelope.read(res[:body], http_status: res[:http_status])
        @warnings << DURABILITY_WARNING if durability_note?(envelope, res[:body])
        envelope
      end

      # `idempotency_not_durable` and `idempotency_store_unavailable` do
      # not fail the call: the contract says the effect proceeds. The
      # result passes through, and the model is told the retry promise is
      # weaker than it looks.
      def durability_note?(envelope, body)
        return true if %i[idempotency_not_durable idempotency_store_unavailable].include?(envelope[:reason])

        result = body.is_a?(Hash) ? body["result"] : nil
        return false unless result.is_a?(Hash)

        %w[idempotency idempotency_status].any? do |key|
          %w[not_durable store_unavailable].include?(result[key].to_s)
        end || result["idempotency_not_durable"] == true
      end

      def decorate(envelope, method, face, operation_id, iri)
        extra = { seam: @seam, method: method.to_s, face: face.to_sym, iri: iri }.compact
        # The id is returned in every result, success or refusal,
        # including a timeout: a refusal that happened after the request
        # may have landed still tells the model which id to reuse.
        extra[:operation_id] = operation_id unless operation_id.to_s.empty?
        warnings = take_warnings
        extra[:warnings] = warnings unless warnings.empty?
        envelope.merge(extra)
      end
    end
  end
end
