# frozen_string_literal: true

require "net/http"
require "json"

module ConfigAdmin
  # Switch's display caller (row 11 slice B). Reads sources and triggers
  # refresh / verify / test on the switch UI plane server-side, so browsers
  # never touch switch directly. This is what lets `:13001` retire.
  # Discovery and verification execute on switch (row 15 stands); config
  # only triggers and displays, on demand with confirm — probes are billed
  # calls, not page loads. Key entry is NOT mirrored here (vault UI owns
  # keys since slice A); this client cannot send key material.
  #
  # Gap 104: Net::HTTP#request does not raise on 4xx. The body is always
  # parsed so refusals arrive as {ok:false, reason:, because:}, not as a
  # bare exception. Do not switch to urlopen / Net::HTTP.get / Faraday
  # raise_error.
  class SwitchClient
    ALLOWED_PATHS = {
      "sources" => true,
      "refresh" => true,
      "verify-tools" => true,
      "test" => true,
    }.freeze

    # Verify loops every enabled model against live vendors: minutes, billed
    # per model. The UI waits the way the old switch page did.
    READ_TIMEOUT = 300

    def initialize(base_url:)
      @base_url = base_url.to_s
    end

    def sources
      get("sources")
    end

    def update(params)
      post("sources", params)
    end

    def refresh(vendor)
      post("refresh", "vendor" => vendor.to_s)
    end

    def verify(vendor: nil, pin: nil)
      args = {}
      args["vendor"] = vendor.to_s if vendor
      args["pin"] = pin.to_s if pin
      post("verify-tools", args)
    end

    def test(pin)
      post("test", "pin" => pin.to_s)
    end

    private

    def get(path)
      call(path, nil)
    end

    def post(path, params)
      call(path, params || {})
    end

    def call(path, params)
      unless ALLOWED_PATHS[path]
        return {
          "ok" => false,
          "reason" => "switch_not_allowlisted",
          "because" => { "caller" => "config-admin", "path" => path },
          "status" => 403,
        }
      end

      uri = endpoint("api/#{path}")
      req = params.nil? ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
      unless params.nil?
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(params)
      end

      res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: READ_TIMEOUT) do |h|
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
