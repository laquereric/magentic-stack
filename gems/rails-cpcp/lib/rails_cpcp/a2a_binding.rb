# frozen_string_literal: true

require "json"
require "securerandom"
require "monitor"

module RailsCpcp
  # Agent2Agent (A2A) envelope over NATS (ADR 0066).
  #
  # A2A is not a container and not ROLE=bus. It is how agents address each
  # other. In-pod transport is NATS (`a2a.<agent>.rpc`). HTTP is not a
  # fallback. Official A2A HTTP/JSON-RPC is a host/external binding, not
  # an in-pod path.
  #
  # A CPCP PDU may ride inside an A2A Part (`data.cpcp`). Domain writes
  # still go through Dispatcher; A2A does not become a second admission log.
  module A2aBinding
    LISTEN_ROLES = %w[back].freeze
    METHODS = {
      "agent/card" => :card,
      "GetAgentCard" => :card,
      "message/send" => :send_message,
      "SendMessage" => :send_message,
      "tasks/get" => :get_task,
      "GetTask" => :get_task
    }.freeze

    module_function

    def url
      ::ENV["MM_NATS_URL"].to_s.strip
    end

    def role
      ::ENV.fetch("ROLE", "back").to_s
    end

    def subject(for_agent = role)
      "a2a.#{for_agent}.rpc"
    end

    def enabled?
      !url.empty?
    end

    def start!
      return unless enabled?
      return unless LISTEN_ROLES.include?(role)
      return if defined?(::Rails) && ::Rails.respond_to?(:env) && ::Rails.env.test?

      t = Thread.new { listen }
      t.abort_on_exception = false
      t.name = "rails-cpcp-a2a-#{role}"
      t
    end

    def exclusive_raw(agent:, payload:, timeout: 5)
      return [false, nil] unless enabled?
      raw = request(agent: agent, payload: payload, timeout: timeout)
      return [true, raw] if raw.to_s.strip != ""
      [true, RailsCpcp::NatsBinding.json_fail("nats_unreachable", "MM_NATS_URL is set; HTTP is not a fallback")]
    end

    def request(agent:, payload:, timeout: 5)
      return nil unless enabled?
      nc = RailsCpcp::NatsBinding.connection
      return nil unless nc

      msg = nc.request(subject(agent), payload.to_s, timeout: timeout)
      msg && (msg.respond_to?(:data) ? msg.data : msg)
    rescue LoadError, StandardError
      nil
    end

    def handle(raw)
      parsed = JSON.parse(raw.to_s)
      unless parsed.is_a?(Hash)
        return json_fail("unparseable_json", "A2A body must be a JSON object")
      end
      id = parsed["id"]
      op = METHODS[parsed["method"].to_s]
      unless op
        return json_fail("a2a_unknown_method", parsed["method"].to_s, id: id)
      end
      result = public_send(op, parsed["params"] || {})
      JSON.generate("jsonrpc" => "2.0", "id" => id, "result" => result)
    rescue JSON::ParserError
      json_fail("unparseable_json", "request body was not JSON")
    rescue StandardError => e
      json_fail("a2a_handle_failed", "#{e.class}: #{e.message}")
    end

    def card(_params = {})
      {
        "name" => "mind-pod-#{role}",
        "description" => "mind-pod #{role}: A2A over NATS, CPCP domain writes",
        "protocolVersion" => "0.2.1",
        "preferredTransport" => "NATS",
        "additionalInterfaces" => [{
          "url" => (url.empty? ? "nats://nats:4222" : url),
          "transport" => "NATS",
          "protocol" => "jsonrpc",
          "subject" => subject
        }],
        "capabilities" => { "streaming" => false, "pushNotifications" => false },
        "defaultInputModes" => ["application/json"],
        "defaultOutputModes" => ["application/json"],
        "skills" => [{
          "id" => "cpcp",
          "name" => "CPCP",
          "description" => "JSON-RPC-LD domain operations as A2A Part data.cpcp"
        }]
      }
    end

    def send_message(params)
      message = (params["message"] || params[:message] || {})
      message = message.transform_keys(&:to_s) if message.respond_to?(:transform_keys)
      parts = Array(message["parts"])
      cpcp = extract_cpcp(parts)
      unless cpcp
        return task(
          state: "rejected",
          message_id: message["messageId"],
          reason: "a2a_unsupported_part",
          because: "in-pod A2A v1 accepts a data.cpcp part; HTTP is not a fallback"
        )
      end
      envelope = Dispatcher.call(cpcp)
      env_h = envelope.respond_to?(:to_h) ? envelope.to_h : envelope
      env_h = JSON.parse(JSON.generate(env_h))
      state = env_h["ok"] == false ? "failed" : "completed"
      task(
        state: state,
        message_id: message["messageId"],
        artifact: { "kind" => "data", "data" => { "cpcp" => env_h } }
      )
    end

    def get_task(params)
      id = (params["id"] || params["taskId"] || params["task_id"]).to_s
      found = store[id]
      return { "id" => id, "status" => { "state" => "unknown" } } unless found
      found
    end

    def extract_cpcp(parts)
      parts.each do |part|
        h = part.is_a?(Hash) ? part.transform_keys(&:to_s) : {}
        data = h["data"]
        data = data.transform_keys(&:to_s) if data.respond_to?(:transform_keys)
        next unless data.is_a?(Hash)
        inner = data["cpcp"]
        inner = inner.transform_keys(&:to_s) if inner.respond_to?(:transform_keys)
        return inner if inner.is_a?(Hash)
      end
      nil
    end

    def task(state:, message_id:, artifact: nil, reason: nil, because: nil)
      id = "urn:uuid:#{SecureRandom.uuid}"
      rec = {
        "id" => id,
        "contextId" => message_id,
        "status" => { "state" => state, "reason" => reason, "because" => because }.compact,
        "artifacts" => artifact ? [{ "artifactId" => "#{id}#artifact", "parts" => [artifact] }] : []
      }
      store[id] = rec
      rec
    end

    def store
      @store_mutex ||= Monitor.new
      @store ||= {}
      @store
    end

    def listen
      nc = RailsCpcp::NatsBinding.connection
      return unless nc

      nc.subscribe(subject) do |msg, *rest|
        data = msg.respond_to?(:data) ? msg.data : msg
        reply = rest[0].to_s
        reply = msg.reply.to_s if reply.empty? && msg.respond_to?(:reply)
        next if reply.empty?
        nc.publish(reply, handle(data))
      end
    rescue LoadError, StandardError => e
      warn("rails-cpcp a2a binding: #{e.class}: #{e.message}")
    end

    def json_fail(reason, because, id: nil)
      JSON.generate(
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => { "code" => -32_000, "message" => reason, "data" => { "ok" => false, "reason" => reason, "because" => because.to_s } }
      )
    end
  end
end
