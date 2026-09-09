# frozen_string_literal: true

require "json"
require "stringio"

module RailsCpcp
  # L7 NATS binding for the same JSON-RPC-LD PDU HTTP carries on POST /_cpcp/rpc
  # (ADR 0065, OSI L8 §10.2). Subject is cpcp.<role>.rpc. Authorization travels
  # in a NATS header, never as a JSON-RPC param (vault contract).
  #
  # nats-pure is required LAZILY so rails-cpcp still loads on stdlib / without
  # the gem. Empty MM_NATS_URL is HTTP-only (tests, host curl). A SET
  # MM_NATS_URL is exclusive: HTTP is not a fallback (ADR 0065 amendment).
  module NatsBinding
    LISTEN_ROLES = %w[back vault bus persist].freeze
    DEFAULT_URL = "nats://nats:4222"

    module_function

    def url
      ::ENV["MM_NATS_URL"].to_s.strip
    end

    def role
      ::ENV.fetch("ROLE", "back").to_s
    end

    def subject(for_role = role)
      "cpcp.#{for_role}.rpc"
    end

    def enabled?
      !url.empty?
    end

    # POST /_cpcp/rpc Rack env. Specs cover this without Rails or nats-pure.
    def rack_env(raw, headers = {})
      raw = raw.to_s
      auth = (headers["Authorization"] || headers["authorization"] || "").to_s
      {
        "REQUEST_METHOD" => "POST",
        "PATH_INFO" => "/_cpcp/rpc",
        "SCRIPT_NAME" => "",
        "QUERY_STRING" => "",
        "SERVER_NAME" => "nats",
        "SERVER_PORT" => "4222",
        "CONTENT_TYPE" => "application/json",
        "CONTENT_LENGTH" => raw.bytesize.to_s,
        "HTTP_AUTHORIZATION" => auth,
        "rack.input" => StringIO.new(raw.b),
        "rack.errors" => StringIO.new,
        "rack.url_scheme" => "http",
        "rack.multithread" => true,
        "rack.multiprocess" => false,
        "rack.run_once" => false
      }
    end

    def handle(raw, headers = {})
      unless defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application
        return json_fail("nats_unbound", "Rails.application is not loaded")
      end
      status, _hdrs, body = ::Rails.application.call(rack_env(raw, headers))
      buf = +""
      body.each { |chunk| buf << chunk.to_s }
      body.close if body.respond_to?(:close)
      return buf unless buf.strip.empty?
      json_fail("empty_nats_response", "status=#{status}")
    rescue StandardError => e
      json_fail("nats_handle_failed", "#{e.class}: #{e.message}")
    end

    def start!
      return unless enabled?
      return unless LISTEN_ROLES.include?(role)
      return if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env.test?

      t = Thread.new { listen }
      t.abort_on_exception = false
      t.name = "rails-cpcp-nats-#{role}"
      t
    end

    # Exclusive in-pod call. Returns [false, nil] when MM_NATS_URL is empty
    # (HTTP is allowed). Returns [true, json] when NATS is configured — the
    # json is the reply or a nats_unreachable refusal. Never returns
    # [true, nil]; that would invite a second transport.
    def exclusive_raw(role:, payload:, token: nil, timeout: 5)
      return [false, nil] unless enabled?
      raw = request(role: role, payload: payload, token: token, timeout: timeout)
      return [true, raw] if raw.to_s.strip != ""
      [true, json_fail("nats_unreachable", "MM_NATS_URL is set; HTTP is not a fallback")]
    end

    def request(role:, payload:, token: nil, timeout: 5)
      return nil unless enabled?
      nc = connection
      return nil unless nc

      hdr = token.to_s.strip.empty? ? nil : { "Authorization" => "Bearer #{token}" }
      msg = if hdr
              nc.request(subject(role), payload.to_s, timeout: timeout, header: hdr)
            else
              nc.request(subject(role), payload.to_s, timeout: timeout)
            end
      msg && (msg.respond_to?(:data) ? msg.data : msg)
    rescue LoadError, StandardError
      nil
    end

    def connection
      require "nats/io/client"
      @conns ||= {}
      u = url
      return @conns[u] if @conns[u]

      @conns[u] = ::NATS.connect(u, connect_timeout: 3, reconnect: true, max_reconnect_attempts: -1)
    rescue LoadError, StandardError
      nil
    end

    def listen
      require "nats/io/client"
      nc = ::NATS.connect(url, connect_timeout: 3, reconnect: true, max_reconnect_attempts: -1)
      nc.subscribe(subject) do |msg, *rest|
        data = msg.respond_to?(:data) ? msg.data : msg
        reply = rest[0].to_s
        reply = msg.reply.to_s if reply.empty? && msg.respond_to?(:reply)
        next if reply.empty?
        headers = msg.respond_to?(:header) && msg.header ? msg.header : {}
        nc.publish(reply, handle(data, headers))
      end
    rescue LoadError, StandardError => e
      warn("rails-cpcp nats binding: #{e.class}: #{e.message}")
    end

    def json_fail(reason, because)
      JSON.generate("ok" => false, "reason" => reason, "because" => because.to_s,
                    "jsonrpc" => "2.0", "id" => nil)
    end
  end
end
