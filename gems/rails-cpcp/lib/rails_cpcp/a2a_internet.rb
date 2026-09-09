# frozen_string_literal: true

module RailsCpcp
  # Host- and internet-facing A2A binding (CPCP a2a/internet, ADR 0068).
  #
  # Same JSON-RPC frame and JSON-LD payloads as A2aBinding (intrapod).
  # Discovery is GET /.well-known/agent-card.json. The JSON-RPC path is
  # POST /_a2a/rpc. preferredTransport is HTTP. This is not an in-pod
  # path: HTTP_BIND=127.0.0.1 does not speak internet A2A (404).
  # Host-published HTTP is a different surface, not a backup path for
  # in-pod calls. HTTP is not a fallback.
  module A2aInternet
    WELL_KNOWN = "/.well-known/agent-card.json"
    RPC_PATH = "/_a2a/rpc"

    module_function

    def role
      ::ENV.fetch("ROLE", "back").to_s
    end

    def bind
      ::ENV.fetch("HTTP_BIND", "127.0.0.1").to_s
    end

    def speaks?
      role == "back" && bind == "0.0.0.0"
    end

    def card(base_url: nil)
      base = (base_url || ::ENV["BASE_IRI"] || "https://mind-pod.local").to_s.sub(%r{/+\z}, "")
      rpc = "#{base}#{RPC_PATH}"
      {
        "@context" => {
          "@vocab" => "https://w3id.org/cpcp/osi8/a2a#",
          "id" => "@id",
          "type" => "@type"
        },
        "id" => "urn:mm:agent:#{role}",
        "type" => "AgentCard",
        "name" => "mind-pod-#{role}",
        "description" => "mind-pod #{role}: A2A over HTTP, CPCP JSON-LD grants",
        "protocolVersion" => "0.2.1",
        "preferredTransport" => "HTTP",
        "url" => rpc,
        "additionalInterfaces" => [{
          "url" => rpc,
          "transport" => "HTTP",
          "protocol" => "jsonrpc"
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
  end
end
