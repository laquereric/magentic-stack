# frozen_string_literal: true

require "net/http"
require "json"

module ConfigAdmin
  # Vault's first caller (ADR 0046 / gap 50). Speaks the decided methods
  # put and list. There is no get: that is the read-back asymmetry, not a
  # gap. Transport is POST /_cpcp/rpc (row 4). The method names did not
  # change with the transport.
  #
  # Gap 104: Net::HTTP#request does not raise on 4xx. The body is always
  # parsed so a 403 arrives as {ok:false, reason:, because:}, not as a
  # bare exception. Do not switch to urlopen / Net::HTTP.get / Faraday
  # raise_error. Do not "fix" a 403 by asking vault for HTTP 200.
  class VaultClient
    ALLOWED = {
      "vault.secret.put" => true,
      "vault.secret.list" => true,
    }.freeze

    def initialize(base_url:, token:)
      @base_url = base_url.to_s
      @token = token.to_s
    end

    def list
      call("vault.secret.list")
    end

    def put(name, value)
      call("vault.secret.put", "name" => name, "value" => value)
    end

    private

    def call(method, params = {})
      ALLOWED.fetch(method) do
        return {
          "ok" => false,
          "reason" => "vault_not_allowlisted",
          "because" => { "caller" => "config-admin", "operation" => method },
          "status" => 403,
        }
      end

      uri = endpoint("_cpcp/rpc")
      req = Net::HTTP::Post.new(uri)
      req["Authorization"] = "Bearer #{@token}"
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => method,
        "params" => params,
      )

      res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 10) do |h|
        h.request(req)
      end
      envelope = parse_body(res.body)
      envelope["status"] = res.code.to_i
      envelope
    end

    def endpoint(path)
      base = @base_url.end_with?("/") ? @base_url : "#{@base_url}/"
      URI.join(base, path.delete_prefix("/"))
    end

    def parse_body(raw)
      JSON.parse(raw.to_s)
    rescue JSON::ParserError
      { "ok" => false, "reason" => "unparseable_vault_body",
        "because" => { "offender" => "body" } }
    end
  end
end
