# frozen_string_literal: true

require "json"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-cal-com"
require "webmock/rspec"

WebMock.disable_net_connect!

module Vv
  module CalCom
    class FakeTransport
      attr_reader :calls

      def initialize(&handler)
        @handler = handler
        @calls = []
      end

      def request(method, path, body: nil, query: nil, headers: {}, auth: true, api_version: nil, form: false)
        @calls << {
          method: method.to_s.downcase.to_sym,
          path: path,
          body: body,
          query: query,
          headers: headers,
          auth: auth,
          api_version: api_version,
          form: form
        }
        @handler.call(@calls.last)
      end
    end
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.order = :random
end
