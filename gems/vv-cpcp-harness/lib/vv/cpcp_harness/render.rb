# frozen_string_literal: true

require "json"

module Vv
  module CpcpHarness
    # What the model sees (design §6.7).
    #
    # A plain sentence first, then the grounded node — the webmcpld rule.
    # The sentence is written by the harness out of things the harness
    # knows: the operation, the id, a count, an outcome. Content written
    # by other people (a note body, a ticket) stays inside the `ld` block
    # and is never merged into it.
    module Render
      MAX_LD_BYTES = 16_000

      module_function

      def result(envelope, tool: nil, warnings: [])
        ld, truncation = truncate(envelope[:ld] || envelope[:result])
        text = [sentence(envelope, tool), *Array(warnings), truncation].compact.reject(&:empty?).join(" ")

        {
          ok: envelope[:ok] == true,
          text: text,
          ld: ld,
          reason: envelope[:reason],
          failure_layer: envelope[:failure_layer],
          operation_id: envelope[:operation_id],
          iri: envelope[:iri] || tool&.iri,
          seam: envelope[:seam] || tool&.seam,
          http_status: envelope[:http_status],
          live_applied: envelope[:live_applied]
        }.reject { |_, v| v.nil? }
      end

      def sentence(envelope, tool = nil)
        name = envelope[:method] || tool&.method_name || tool&.name || "the operation"
        named = envelope[:operation_id] ? "#{name} (operationId #{envelope[:operation_id]})" : name

        return refusal_sentence(named, envelope) unless envelope[:ok] == true

        # A native tool writes its own sentence; the harness does not
        # paraphrase it. Seam results never take this path, because what
        # a seam returns is data and may carry someone else's words.
        if envelope[:text].is_a?(String) && !envelope[:text].empty?
          own = envelope[:text]
          own = "#{own} (operationId #{envelope[:operation_id]})" if envelope[:operation_id]
          return own
        end

        # A recording is not an application, and a reader must never
        # mistake one for the other.
        if envelope[:live_applied] == false
          horizon = envelope[:effective] ? " It becomes effective #{envelope[:effective]}." : ""
          return "#{named} was recorded, not applied.#{horizon}"
        end

        "#{named} succeeded#{summary(envelope[:result])}."
      end

      def refusal_sentence(named, envelope)
        reason = envelope[:reason]
        because = Envelope.text(envelope[:because])
        line = "#{named} was refused: #{reason}"
        line += " — #{because}" unless because.empty?
        line += "."

        if (r = envelope[:restoration])
          line += " State reached: #{r[:state_reached]}. Inconsistency: #{r[:inconsistency]}. " \
                  "Restore when #{r[:restore_when]} by #{r[:restore_action]}."
        end
        line
      end

      def summary(result)
        return "" unless result.is_a?(Hash)

        graph = result["@graph"]
        return " with #{graph.length} item#{graph.length == 1 ? "" : "s"}" if graph.is_a?(Array)

        ""
      end

      # Truncation applies to the grounded node only. A cut `@graph` says
      # how many items were dropped, so the model knows to narrow its PULL
      # rather than believing it has seen everything.
      def truncate(ld, max_bytes: MAX_LD_BYTES)
        return [nil, nil] if ld.nil?

        json = JSON.generate(ld)
        return [ld, nil] if json.bytesize <= max_bytes

        graph = ld.is_a?(Hash) ? ld.dig("result", "@graph") : nil
        unless graph.is_a?(Array) && !graph.empty?
          return [{ "truncated" => true, "bytes" => json.bytesize, "preview" => json[0, max_bytes] },
                  "The result was too large to show in full."]
        end

        kept = graph
        kept = kept[0...(kept.length / 2)] while kept.length > 1 && JSON.generate(shrink(ld, kept)).bytesize > max_bytes
        omitted = graph.length - kept.length
        [shrink(ld, kept),
         "#{omitted} of #{graph.length} items were omitted; narrow the read to see the rest."]
      end

      def shrink(ld, kept)
        copy = deep_dup(ld)
        copy["result"]["@graph"] = kept
        copy["result"]["cpcp:truncated"] = { "kept" => kept.length }
        copy
      end

      def deep_dup(value)
        case value
        when Hash then value.to_h { |k, v| [k, deep_dup(v)] }
        when Array then value.map { |v| deep_dup(v) }
        else value
        end
      end

      # Two text blocks, sentence first; `ok: false` is an error whatever
      # the HTTP status was, including a 200 domain refusal.
      def claude(rendered)
        blocks = [{ "type" => "text", "text" => rendered[:text] }]
        unless rendered[:ld].nil?
          blocks << { "type" => "text", "text" => JSON.pretty_generate(rendered[:ld]) }
        end
        { "content" => blocks, "is_error" => !rendered[:ok] }
      end

      # An MCP `tools/call` result. Same rule as the Claude blocks —
      # sentence first, grounded node after — and the same rule about
      # refusals: `ok: false` is `isError: true`, whatever the HTTP
      # status was on the seam's side of the call.
      #
      # `_meta` carries the CPCP identity for the client's own logs. It
      # is server-to-client metadata, not model-facing text, which is
      # where linked data belongs when the JSON may not survive.
      def mcp(rendered, meta_prefix: Mcp::META_PREFIX)
        result = {
          "resultType" => "complete",
          "content" => [{ "type" => "text", "text" => rendered[:text] }],
          "isError" => !rendered[:ok]
        }

        unless rendered[:ld].nil?
          result["content"] << { "type" => "text", "text" => JSON.pretty_generate(rendered[:ld]) }
          result["structuredContent"] = rendered[:ld] if rendered[:ld].is_a?(Hash) || rendered[:ld].is_a?(Array)
        end

        meta = {
          "#{meta_prefix}iri" => rendered[:iri],
          "#{meta_prefix}seam" => rendered[:seam],
          "#{meta_prefix}operationId" => rendered[:operation_id],
          "#{meta_prefix}reason" => rendered[:reason]&.to_s,
          "#{meta_prefix}failureLayer" => rendered[:failure_layer]&.to_s,
          "#{meta_prefix}liveApplied" => rendered[:live_applied]
        }.reject { |_, v| v.nil? }
        result["_meta"] = meta unless meta.empty?

        result
      end

      # One string: the sentence, a blank line, then the JSON.
      def open_code(rendered)
        body = rendered[:ld].nil? ? "" : "\n\n#{JSON.pretty_generate(rendered[:ld])}"
        prefix = rendered[:ok] ? "" : "Error: "
        "#{prefix}#{rendered[:text]}#{body}"
      end
    end
  end
end
