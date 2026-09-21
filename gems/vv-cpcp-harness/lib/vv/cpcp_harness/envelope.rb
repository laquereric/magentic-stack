# frozen_string_literal: true

require "json"

module Vv
  module CpcpHarness
    # Never-raise boundary. Every public method in this gem returns
    # `{ ok: true, result:, ... }` or `{ ok: false, reason:, because: }`.
    #
    # `read` is the client half of the contract's envelope rules: a
    # refusal arrives in one of two shapes that are deliberately not
    # unified, so a reader must look in both places, and it arrives with
    # an HTTP status that is a second signal rather than the same one.
    module Envelope
      # `cpcp.restoration` is all-or-nothing: exactly these four members,
      # none blank, or the object is dropped.
      RESTORATION_MEMBERS = %w[state_reached inconsistency restore_when restore_action].freeze

      module_function

      def ok(result: nil, **extra)
        { ok: true, result: result }.merge(compact(extra))
      end

      def refuse(reason, because, **extra)
        reason = reason.to_s.to_sym
        layer = extra.delete(:failure_layer) || Reasons.layer_for(reason)
        {
          ok: false,
          reason: reason,
          because: because,
          failure_layer: layer&.to_sym
        }.compact.merge(compact(extra))
      end

      # Read a seam response body into a harness envelope.
      #
      #   read(payload, http_status: 200)
      #
      # The status is carried, never consulted for meaning: a domain
      # decision such as `grounding_refused` arrives as 200, and a client
      # that inferred success from the status would report a refusal as a
      # completed write.
      def read(payload, http_status: nil)
        unless payload.is_a?(Hash)
          return refuse(:seam_body_unparseable,
                        "expected a JSON object envelope, got #{payload.class}",
                        http_status: http_status)
        end

        unless payload.key?("ok")
          return refuse(:seam_body_unparseable, "envelope has no ok member",
                        http_status: http_status, ld: payload)
        end

        payload["ok"] == true ? read_success(payload, http_status) : read_refusal(payload, http_status)
      end

      def read_success(payload, http_status)
        result = payload["result"]
        extra = {}
        if result.is_a?(Hash)
          extra[:live_applied] = result["live_applied"] if result.key?("live_applied")
          extra[:effective] = result["effective"] if result.key?("effective")
        end
        ok(result: result,
           http_status: http_status,
           rpc_id: payload["id"],
           context: payload["@context"],
           ld: payload,
           **extra)
      end
      private_class_method :read_success

      def read_refusal(payload, http_status)
        error = payload["error"].is_a?(Hash) ? payload["error"] : {}
        # Nested form first (`error.reason`), then flat (top-level).
        reason = error["reason"] || payload["reason"]
        because = error.key?("because") ? error["because"] : payload["because"]
        layer = error["failure_layer"] || payload["failure_layer"]

        if reason.to_s.empty?
          return refuse(:seam_body_unparseable, "ok:false without a reason in either form",
                        http_status: http_status, ld: payload)
        end

        refuse(reason, because,
               http_status: http_status,
               failure_layer: layer,
               rpc_id: payload["id"],
               restoration: restoration(payload),
               ld: payload)
      end
      private_class_method :read_refusal

      # All four members or nothing. A partial restoration is worse than
      # none: it reads like advice and is not.
      def restoration(payload)
        object = payload.is_a?(Hash) ? payload.dig("cpcp", "restoration") : nil
        return nil unless object.is_a?(Hash)
        return nil unless RESTORATION_MEMBERS.all? { |m| !blank?(object[m]) }
        return nil unless (object.keys - RESTORATION_MEMBERS).empty?

        RESTORATION_MEMBERS.each_with_object({}) { |m, h| h[m.to_sym] = object[m] }
      end

      # `because` is a string on most seams and an object on some
      # hand-rolled ones. Both are carried through untouched; this is how
      # either becomes a sentence.
      def text(value)
        case value
        when nil then ""
        when String then value
        when Hash, Array then JSON.generate(value)
        else value.to_s
        end
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def compact(hash)
        hash.reject { |_, v| v.nil? }
      end
    end
  end
end
