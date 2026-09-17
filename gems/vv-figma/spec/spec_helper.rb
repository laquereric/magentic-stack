# frozen_string_literal: true

require "json"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-figma"
require "webmock/rspec"

WebMock.disable_net_connect!

module Vv
  module Figma
    class FakeTransport
      attr_reader :calls, :uri

      def initialize(uri: "https://api.figma.com", &handler)
        @uri = uri
        @handler = handler
        @calls = []
      end

      def request(method, path, body: nil, query: nil, headers: {}, form: false, auth: true, basic: nil)
        @calls << {
          method: method.to_s.downcase.to_sym,
          path: path,
          body: body,
          query: query,
          headers: headers,
          form: form,
          auth: auth,
          basic: basic
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
