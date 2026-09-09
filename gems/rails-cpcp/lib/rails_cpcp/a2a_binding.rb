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
  # A CPCP grant rides as a JSON-LD Context/Effect node in a DataPart
  # (`application/ld+json`). Domain writes still go through Dispatcher;
  # A2A does not become a second admission log. Nested JSON-RPC under
  # data.cpcp is a2a_json_not_jsonld (ADR 0067). HTTP is not a fallback.
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

    def exclusive_raw(agent:, payload:, token: nil, timeout: 5)
      return [false, nil] unless enabled?
      raw = request(agent: agent, payload: payload, token: token, timeout: timeout)
      return [true, raw] if raw.to_s.strip != ""
      [true, RailsCpcp::NatsBinding.json_fail("nats_unreachable", "MM_NATS_URL is set; HTTP is not a fallback")]
    end

    def request(agent:, payload:, token: nil, timeout: 5)
      return nil unless enabled?
      nc = RailsCpcp::NatsBinding.connection
      return nil unless nc

      hdr = token.to_s.strip.empty? ? nil : { "Authorization" => "Bearer #{token}" }
      msg = if hdr
              nc.request(subject(agent), payload.to_s, timeout: timeout, header: hdr)
            else
              nc.request(subject(agent), payload.to_s, timeout: timeout)
            end
      msg && (msg.respond_to?(:data) ? msg.data : msg)
    rescue LoadError, StandardError
      nil
    end

    def handle(raw, headers: {}, ctx: nil)
      parsed = JSON.parse(raw.to_s)
      unless parsed.is_a?(Hash)
        return json_fail("unparseable_json", "A2A body must be a JSON object")
      end
      id = parsed["id"]
      op = METHODS[parsed["method"].to_s]
      unless op
        return json_fail("a2a_unknown_method", parsed["method"].to_s, id: id)
      end
      params = parsed["params"] || {}
      result = case op
               when :card then card(params)
               when :send_message then send_message(params, ctx: ctx)
               when :get_task then get_task(params)
               end
      JSON.generate("jsonrpc" => "2.0", "id" => id, "result" => result)
    rescue JSON::ParserError
      json_fail("unparseable_json", "request body was not JSON")
    rescue StandardError => e
      json_fail("a2a_handle_failed", "#{e.class}: #{e.message}")
    end

    def card(_params = {})
      {
        "@context" => {
          "@vocab" => "https://w3id.org/cpcp/osi8/a2a#",
          "id" => "@id",
          "type" => "@type"
        },
        "id" => "urn:mm:agent:#{role}",
        "type" => "AgentCard",
        "name" => "mind-pod-#{role}",
        "description" => "mind-pod #{role}: A2A over NATS, CPCP JSON-LD grants",
        "protocolVersion" => "0.2.1",
        "preferredTransport" => "NATS",
        "additionalInterfaces" => [{
          "url" => (url.empty? ? "nats://nats:4222" : url),
          "transport" => "NATS",
          "protocol" => "jsonrpc",
          "subject" => subject
        }],
        "capabilities" => { "streaming" => false, "pushNotifications" => false },
        "defaultInputModes" => ["application/ld+json"],
        "defaultOutputModes" => ["application/ld+json"],
        "skills" => [{
          "id" => "cpcp",
          "name" => "CPCP",
          "description" => "JSON-LD Context (PULL) and Effect (PUSH) as A2A DataPart"
        }]
      }
    end

    def send_message(params, ctx: nil)
      message = (params["message"] || params[:message] || {})
      message = message.transform_keys(&:to_s) if message.respond_to?(:transform_keys)
      parts = Array(message["parts"])
      grant, err = extract_grant(parts)
      if err
        return task(
          state: "rejected",
          message_id: message["id"] || message["messageId"],
          reason: err[:reason],
          because: err[:because]
        )
      end
      unless grant
        return task(
          state: "rejected",
          message_id: message["id"] || message["messageId"],
          reason: "a2a_unsupported_part",
          because: "in-pod A2A v1 accepts a JSON-LD Context or Effect DataPart; HTTP is not a fallback"
        )
      end
      envelope = Dispatcher.call(ld_to_rpc(grant), ctx: ctx)
      env_h = envelope.respond_to?(:to_h) ? envelope.to_h : envelope
      env_h = JSON.parse(JSON.generate(env_h))
      env_h["@context"] ||= RailsCpcp::Envelope.context
      env_h["type"] ||= env_h["ok"] == false ? ["cpcp:Refusal"] : ["cpcp:Result"]
      state = env_h["ok"] == false ? "failed" : "completed"
      task(
        state: state,
        message_id: message["id"] || message["messageId"],
        artifact: {
          "type" => "DataPart",
          "mediaType" => "application/ld+json",
          "data" => env_h
        }
      )
    end

    def get_task(params)
      id = (params["id"] || params["taskId"] || params["task_id"]).to_s
      found = store[id]
      return found if found
      {
        "@context" => {
          "@vocab" => "https://w3id.org/cpcp/osi8/a2a#",
          "cpcp" => "https://w3id.org/cpcp/ns#",
          "id" => "@id",
          "type" => "@type"
        },
        "id" => id,
        "type" => "Task",
        "status" => { "type" => "TaskStatus", "state" => "unknown" }
      }
    end

    def extract_grant(parts)
      parts.each do |part|
        h = part.is_a?(Hash) ? part.transform_keys(&:to_s) : {}
        data = h["data"]
        data = data.transform_keys(&:to_s) if data.respond_to?(:transform_keys)
        next unless data.is_a?(Hash)
        if data["cpcp"].is_a?(Hash) || nested_jsonrpc?(data)
          return [nil, { reason: "a2a_json_not_jsonld",
                         because: "Part.data must be a JSON-LD Context or Effect, not nested JSON-RPC" }]
        end
        next unless data["method"].to_s != ""
        unless data.key?("@context")
          return [nil, { reason: "a2a_json_not_jsonld",
                         because: "JSON-LD @context is required on the grant node" }]
        end
        return [data, nil]
      end
      [nil, nil]
    end

    def nested_jsonrpc?(node)
      node.is_a?(Hash) && node["jsonrpc"].to_s == "2.0" && !node.key?("@context")
    end

    def ld_to_rpc(node)
      {
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => node["method"],
        "params" => node["params"].is_a?(Hash) ? node["params"] : {},
        "operationId" => node["operationId"]
      }.compact
    end

    def task(state:, message_id:, artifact: nil, reason: nil, because: nil)
      id = "urn:uuid:#{SecureRandom.uuid}"
      rec = {
        "@context" => {
          "@vocab" => "https://w3id.org/cpcp/osi8/a2a#",
          "cpcp" => "https://w3id.org/cpcp/ns#",
          "id" => "@id",
          "type" => "@type"
        },
        "id" => id,
        "type" => "Task",
        "contextId" => message_id,
        "status" => { "type" => "TaskStatus", "state" => state, "reason" => reason, "because" => because }.compact,
        "artifacts" => artifact ? [{ "id" => "#{id}#artifact", "type" => "Artifact", "parts" => [artifact] }] : []
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
        headers = msg.respond_to?(:header) && msg.header ? msg.header : {}
        nc.publish(reply, handle(data, headers: headers))
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
