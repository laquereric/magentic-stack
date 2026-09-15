# frozen_string_literal: true

require "json"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "vv-miro"
require "webmock/rspec"

WebMock.disable_net_connect!

module Vv
  module Miro
    class FakeTransport
      attr_reader :calls, :uri

      def initialize(uri: "https://api.miro.com", &handler)
        @uri = uri
        @handler = handler
        @calls = []
      end

      def request(method, path, body: nil, query: nil, headers: {}, form: false, auth: true)
        @calls << {
          method: method.to_s.downcase.to_sym,
          path: path,
          body: body,
          query: query,
          headers: headers,
          form: form,
          auth: auth
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
