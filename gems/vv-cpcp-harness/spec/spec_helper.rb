# frozen_string_literal: true

require "json"
require "tmpdir"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-cpcp-harness"
require "webmock/rspec"

WebMock.disable_net_connect!

module Vv
  module CpcpHarness
    # A seam that never leaves the process. The block receives each call
    # and answers with an exchange (`exchange`) or a transport refusal.
    class FakeTransport
      attr_reader :calls, :cid_calls

      def initialize(cid_payload: nil, cid_response: nil, &handler)
        @handler = handler
        @cid_payload = cid_payload
        @cid_response = cid_response
        @calls = []
        @cid_calls = 0
      end

      def rpc(method:, params: {}, operation_id: nil, rpc_id: nil)
        @calls << { method: method, params: params, operation_id: operation_id, rpc_id: rpc_id }
        @handler.call(@calls.last, @calls.length)
      end

      def cid
        @cid_calls += 1
        return @cid_response if @cid_response

        exchange(200, @cid_payload)
      end

      def up
        exchange(200, { "ok" => true })
      end

      def exchange(status, body, headers: {})
        { exchanged: true, http_status: status, headers: headers, body: body,
          raw: body.nil? ? "" : JSON.generate(body), parse_error: nil }
      end
    end

    module SpecHelpers
      FIXTURES = File.expand_path("../cpcp/cids", __dir__)

      def exchange(status, body, headers: {})
        { exchanged: true, http_status: status, headers: headers, body: body,
          raw: body.nil? ? "" : JSON.generate(body), parse_error: nil }
      end

      def unreachable(because = "Errno::ECONNREFUSED: refused")
        Envelope.refuse(:seam_unreachable, because, transport_error: :connection)
      end

      def cid_payload(name)
        JSON.parse(File.read(File.join(FIXTURES, "#{name}.cid.json")))
      end

      def push_cid
        cid_payload("demo-push-note")
      end

      def pull_cid
        cid_payload("demo-pull-note")
      end

      def ok_envelope(result, id: 1)
        { "jsonrpc" => "2.0", "id" => id, "ok" => true, "result" => result }
      end

      def nested_refusal(reason, because, id: 1)
        { "jsonrpc" => "2.0", "id" => id, "ok" => false,
          "error" => { "reason" => reason, "because" => because } }
      end

      def flat_refusal(reason, because, id: 1)
        { "jsonrpc" => "2.0", "id" => id, "ok" => false, "reason" => reason, "because" => because }
      end

      # A seam config pointing at a fixture snapshot.
      def seam(name: "back", payload: nil, **extra)
        {
          name: name,
          endpoint: "https://back.example/_cpcp",
          cid_payload: payload || push_cid,
          credential: -> { "token" },
          status_profile: "dual-v1"
        }.merge(extra)
      end
    end
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.order = :random
  c.include Vv::CpcpHarness::SpecHelpers
end
