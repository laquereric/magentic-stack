# frozen_string_literal: true

require "json"

# Caller allowlist for the vault HTTP API. Identity AND operation, not identity
# alone (ADR 0046). No default token: missing/empty/unparseable is a refusal.
module Vault
  class Allowlist
    OPS = %w[put list get].freeze

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
        raise Unparseable.new("vault_callers_missing", { "offender" => "VAULT_CALLERS" })
      end
      data = JSON.parse(raw)
      unless data.is_a?(Hash) && !data.empty?
        raise Unparseable.new("vault_callers_unparseable", { "offender" => "VAULT_CALLERS", "because" => "want a non-empty object" })
      end
      callers = {}
      tokens = {}
      data.each do |id, spec|
        id = id.to_s
        unless spec.is_a?(Hash)
          raise Unparseable.new("vault_callers_unparseable", { "offender" => id, "because" => "caller spec must be an object" })
        end
        token = spec["token"].to_s
        if token.empty?
          raise Unparseable.new("vault_callers_token_missing", { "offender" => id })
        end
        if tokens.key?(token)
          raise Unparseable.new("vault_callers_token_collision", { "offender" => [tokens[token], id] })
        end
        ops = Array(spec["operations"]).map(&:to_s)
        if ops.empty? || (ops - OPS).any?
          raise Unparseable.new("vault_callers_operations_invalid", { "offender" => id, "operations" => ops })
        end
        tokens[token] = id
        callers[token] = Caller.new(id: id, token: token, operations: ops)
      end
      new(callers)
    rescue JSON::ParserError => e
      raise Unparseable.new("vault_callers_unparseable", { "offender" => "VAULT_CALLERS", "because" => e.class.name })
    end

    def initialize(callers_by_token)
      @callers_by_token = callers_by_token
    end

    def authenticate!(token, operation)
      if token.to_s.empty?
        raise Unauthenticated.new("vault_unauthenticated", { "offender" => "Authorization", "because" => "absent" })
      end
      caller = @callers_by_token[token]
      unless caller
        raise Unauthenticated.new("vault_unauthenticated", { "offender" => "Authorization", "because" => "unknown" })
      end
      unless caller.operations.include?(operation)
        raise Forbidden.new("vault_not_allowlisted", { "caller" => caller.id, "operation" => operation })
      end
      caller
    end
  end
end
