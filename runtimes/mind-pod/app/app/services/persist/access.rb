# frozen_string_literal: true

# Caller allowlist for ROLE=persist (row 8; 0051 "named caller with an
# explicit operation", 0046 pattern). PERSIST_CALLERS is a JSON object
# mapping caller id to {token, operations}; missing or unparseable fails
# closed at boot. The Bearer token is the Authorization header, never a
# JSON-RPC param.
module Persist
  class Access
    OPS = %w[set get].freeze

    class Error < StandardError
      attr_reader :reason, :because
      def initialize(reason, because)
        @reason = reason
        @because = because
        super(reason)
      end
    end

    Unauthenticated = Class.new(Error)
    Forbidden = Class.new(Error)
    Unparseable = Class.new(Error)

    Caller = Struct.new(:id, :token, :operations, keyword_init: true)

    def self.parse!(raw)
      if raw.nil? || raw.to_s.strip.empty?
        raise Unparseable.new("persist_callers_missing", { "offender" => "PERSIST_CALLERS" })
      end
      data = JSON.parse(raw)
      unless data.is_a?(Hash) && !data.empty?
        raise Unparseable.new("persist_callers_unparseable", { "offender" => "PERSIST_CALLERS", "because" => "want a non-empty object" })
      end
      callers = {}
      tokens = {}
      data.each do |id, spec|
        id = id.to_s
        unless spec.is_a?(Hash)
          raise Unparseable.new("persist_callers_unparseable", { "offender" => id, "because" => "caller spec must be an object" })
        end
        token = spec["token"].to_s
        if token.empty?
          raise Unparseable.new("persist_callers_token_missing", { "offender" => id })
        end
        if tokens.key?(token)
          raise Unparseable.new("persist_callers_token_collision", { "offender" => [tokens[token], id] })
        end
        ops = Array(spec["operations"]).map(&:to_s)
        unknown = ops - OPS
        unless unknown.empty?
          raise Unparseable.new("persist_callers_unknown_operation", { "offender" => id, "because" => "want subset of #{OPS}" })
        end
        tokens[token] = id
        callers[id] = Caller.new(id: id, token: token, operations: ops)
      end
      new(callers: callers, by_token: tokens)
    end

    def initialize(callers:, by_token:)
      @callers = callers
      @by_token = by_token
    end

    def authenticate!(token)
      id = @by_token[token.to_s]
      if id.nil? || token.to_s.empty?
        raise Unauthenticated.new("persist_unauthenticated", { "offender" => "Authorization" })
      end
      @callers[id]
    end

    def authorize!(caller, op)
      unless caller.operations.include?(op.to_s)
        raise Forbidden.new("persist_forbidden", { "caller" => caller.id, "operation" => op.to_s })
      end
      true
    end
  end
end
