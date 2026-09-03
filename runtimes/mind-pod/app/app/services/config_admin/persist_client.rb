# frozen_string_literal: true

require "net/http"
require "json"

module ConfigAdmin
  # Persist's first caller (row 41). Speaks the decided methods
  # persist.path.set and persist.path.get. Transport is POST /_cpcp/rpc
  # (row 8). Path options offered by the UI come from the row-39 closed
  # set, never free text.
  #
  # Gap 104: Net::HTTP#request does not raise on 4xx. The body is always
  # parsed so a 403 arrives as {ok:false, reason:, because:}, not as a
  # bare exception. Do not switch to urlopen / Net::HTTP.get / Faraday
  # raise_error. Do not "fix" a 403 by asking persist for HTTP 200.
  class PersistClient
    ALLOWED = {
      "persist.path.set" => true,
      "persist.path.get" => true,
    }.freeze

    def initialize(base_url:, token:)
      @base_url = base_url.to_s
      @token = token.to_s
    end

    def get(store)
      call("persist.path.get", "store" => store.to_s)
    end

    def set(store, path)
      call("persist.path.set", "store" => store.to_s, "path" => path.to_s)
    end

    private

    def call(method, params = {})
      ALLOWED.fetch(method) do
        return {
          "ok" => false,
          "reason" => "persist_not_allowlisted",
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

    def parse_body(body)
      parsed = JSON.parse(body.to_s)
      parsed.is_a?(Hash) ? parsed : { "ok" => false, "reason" => "unparseable_body", "because" => {} }
    rescue JSON::ParserError
      { "ok" => false, "reason" => "unparseable_body", "because" => {} }
    end
  end
end
