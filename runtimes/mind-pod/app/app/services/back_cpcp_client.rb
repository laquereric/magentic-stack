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
    response = Net::HTTP.post(
      URI.join(@back_url.end_with?("/") ? @back_url : "#{@back_url}/", "_cpcp/rpc"),
      JSON.generate(
        jsonrpc: "2.0",
        method: operation,
        params: params,
        id: SecureRandom.uuid
      ),
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
        source: "front/back_cpcp_client"
      )
    end
    { "ok" => false, "error" => { "reason" => "back_unavailable", "because" => { "detail" => e.class.name } } }
  end
end
