# frozen_string_literal: true

require "net/http"
require "json"
require "securerandom"

# FRONT-only HTTP CPCP client. Never touches Active Record.
class BackCpcpClient
  def initialize(back_url = Rails.application.config.x.back_url)
    @back_url = back_url
  end

  def pull(operation, params = {})
    payload = JSON.generate(
      jsonrpc: "2.0",
      method: operation,
      params: params,
      id: SecureRandom.uuid
    )
    if ::ENV["MM_NATS_URL"].to_s.strip != ""
      unless defined?(::RailsCpcp::NatsBinding)
        return { "ok" => false, "error" => { "reason" => "nats_unbound", "because" => { "detail" => "MM_NATS_URL is set; HTTP is not a fallback" } } }
      end
      _exclusive, raw = ::RailsCpcp::NatsBinding.exclusive_raw(role: "back", payload: payload)
      body = JSON.parse(raw)
      return body if body["ok"] == true
      return { "ok" => false, "error" => body["error"] || { "reason" => body["reason"] || "nats_unreachable", "because" => body["because"] || {} } }
    end
    response = Net::HTTP.post(
      URI.join(@back_url.end_with?("/") ? @back_url : "#{@back_url}/", "_cpcp/rpc"),
      payload,
      "Content-Type" => "application/json"
    )
    body = JSON.parse(response.body)
    return body if body["ok"] == true

    { "ok" => false, "error" => body["error"] || { "reason" => "unknown", "because" => {} } }
  rescue StandardError => e
    if defined?(::RailsCpcp::RefusalLog)
      ::RailsCpcp::RefusalLog.record(
        reason: "back_unavailable",
        because: e.class.name,
        source: "front/back_cpcp_client",
        restoration: {
          "state_reached" => "FRONT got no CPCP response from BACK",
          "inconsistency" => "browser view has no current BACK state",
          "restore_when" => "BACK /_cpcp answers",
          "restore_action" => "retry the PULL; do not write locally"
        }
      )
    end
    { "ok" => false, "error" => { "reason" => "back_unavailable", "because" => { "detail" => e.class.name } } }
  end
end
