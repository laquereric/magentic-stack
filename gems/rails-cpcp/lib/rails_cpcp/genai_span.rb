# frozen_string_literal: true
require "json"
require "securerandom"

module RailsCpcp
  # GenAI semantic-convention spans at /_cpcp. No OTEL SDK (GAP 74).
  # Local append is the floor; OTLP is optional and never raises.
  # Logfire is not a dependency. Prompts and credentials are not attributes.
  module GenaiSpan
    module_function

    SCOPE_NAME = "rails-cpcp/genai"
    SCOPE_VERSION = "1"
    ENV_LOG = "CPCP_GENAI_SPAN_LOG"
    FORBIDDEN = %w[
      authorization cookie set-cookie session_token api_key password email token
      prompt messages content completion gen_ai.input.messages gen_ai.output.messages
      gen_ai.prompt gen_ai.completion
    ].freeze

    def emit(operation:, suffix:, kind:, traceparent: nil, ok: true, reason: nil, attributes: {}, duration_ms: 0)
      span = build(
        operation: operation,
        suffix: suffix,
        kind: kind,
        traceparent: traceparent,
        ok: ok,
        reason: reason,
        attributes: attributes,
        duration_ms: duration_ms
      )
      write_local(span)
      export_otlp(span)
      span
    rescue StandardError
      nil
    end

    def around(request:, traceparent: nil)
      t0 = monotonic_ms
      env = nil
      begin
        env = yield
      ensure
        method = (request && request["method"]).to_s
        params = (request && request["params"]) || {}
        opid = (request && (request["operationId"] || params["operationId"])).to_s
        failed = env.is_a?(Hash) && env["ok"] == false
        emit(
          operation: "invoke_agent",
          suffix: method,
          kind: "SERVER",
          traceparent: traceparent,
          ok: !failed,
          reason: failed ? env.dig("error", "reason") : nil,
          attributes: {
            "rpc.method" => method,
            "cpcp.operation_id" => opid,
            "gen_ai.agent.name" => "cpcp"
          },
          duration_ms: monotonic_ms - t0
        )
      end
      env
    end

    def build(operation:, suffix:, kind:, traceparent:, ok:, reason:, attributes:, duration_ms:)
      ids = parse_traceparent(traceparent)
      attrs = compact_attrs(
        { "gen_ai.operation.name" => operation.to_s }.merge(attributes || {})
      )
      attrs["error.type"] = reason.to_s if ok == false && reason && !reason.to_s.empty?
      {
        "name" => "#{operation} #{suffix}".strip,
        "kind" => kind.to_s,
        "traceId" => ids[:trace_id],
        "spanId" => SecureRandom.hex(8),
        "parentSpanId" => ids[:parent_span_id],
        "status" => { "code" => ok == false ? "ERROR" : "UNSET" },
        "durationMs" => duration_ms.to_f,
        "attributes" => attrs,
        "otel.scope.name" => SCOPE_NAME,
        "otel.scope.version" => SCOPE_VERSION
      }.compact
    end

    def parse_traceparent(header)
      parts = header.to_s.strip.split("-")
      if parts.length >= 4 && parts[1].match?(/\A[0-9a-f]{32}\z/i) && parts[2].match?(/\A[0-9a-f]{16}\z/i)
        { trace_id: parts[1].downcase, parent_span_id: parts[2].downcase }
      else
        { trace_id: SecureRandom.hex(16), parent_span_id: nil }
      end
    end

    def compact_attrs(attrs)
      out = {}
      attrs.each do |key, value|
        k = key.to_s
        next if FORBIDDEN.include?(k) || FORBIDDEN.include?(k.downcase)
        next if value.nil? || value.to_s.empty?

        out[k] = value
      end
      out
    end

    def log_path
      explicit = ENV[ENV_LOG].to_s
      return explicit unless explicit.empty?

      File.join(File.dirname(RefusalLog.log_path), "cpcp_genai_spans.jsonl")
    end

    def write_local(span)
      line = JSON.generate("gen_ai_span" => span)
      File.open(log_path, "a") { |io| io.puts(line) }
    end

    def export_otlp(span)
      url = ENV["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"].to_s.strip
      return if url.empty?

      require "net/http"
      require "uri"
      uri = URI.parse(url)
      return unless uri.is_a?(URI::HTTP)

      body = {
        "resourceSpans" => [{
          "resource" => { "attributes" => [{ "key" => "service.name", "value" => { "stringValue" => "cpcp" } }] },
          "scopeSpans" => [{
            "scope" => { "name" => SCOPE_NAME, "version" => SCOPE_VERSION },
            "spans" => [{
              "traceId" => span["traceId"],
              "spanId" => span["spanId"],
              "parentSpanId" => span["parentSpanId"].to_s,
              "name" => span["name"],
              "kind" => 2,
              "attributes" => (span["attributes"] || {}).map { |k, v| otlp_attr(k, v) }
            }]
          }]
        }]
      }
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 1
      http.read_timeout = 1
      req = Net::HTTP::Post.new(uri.request_uri)
      req["content-type"] = "application/json"
      req.body = JSON.generate(body)
      http.request(req)
    rescue StandardError
      nil
    end

    def otlp_attr(key, value)
      if value.is_a?(Numeric)
        { "key" => key, "value" => { "intValue" => value.to_i.to_s } }
      else
        { "key" => key, "value" => { "stringValue" => value.to_s } }
      end
    end

    def monotonic_ms
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
    end
  end
end
