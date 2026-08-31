# frozen_string_literal: true

module Vault
  # Request handler for the vault HTTP surface. Values are returned only by
  # `get`, which the allowlist must not grant to config-admin (read-back
  # asymmetry, ADR 0046).
  class Api
    def initialize(allowlist:, store:)
      @allowlist = allowlist
      @store = store
    end

    def put(token, name, value)
      caller = @allowlist.authenticate!(token, "put")
      meta = @store.put(name, value)
      { status: 200, json: { "ok" => true, "result" => meta.merge("caller" => caller.id) } }
    rescue Vault::Allowlist::Unauthenticated, Vault::Allowlist::Forbidden, Vault::Store::Error => e
      fail_of(e)
    end

    def list(token)
      caller = @allowlist.authenticate!(token, "list")
      items = @store.list
      { status: 200, json: { "ok" => true, "result" => { "items" => items, "caller" => caller.id } } }
    rescue Vault::Allowlist::Unauthenticated, Vault::Allowlist::Forbidden, Vault::Store::Error => e
      fail_of(e)
    end

    def get(token, name)
      caller = @allowlist.authenticate!(token, "get")
      rec = @store.get(name)
      { status: 200, json: { "ok" => true, "result" => rec.merge("caller" => caller.id) } }
    rescue Vault::Allowlist::Unauthenticated, Vault::Allowlist::Forbidden, Vault::Store::Error => e
      fail_of(e)
    end

    private

    def fail_of(err)
      status = case err
               when Vault::Allowlist::Unauthenticated then 401
               when Vault::Allowlist::Forbidden then 403
               when Vault::Store::Error
                 err.reason == "vault_secret_absent" ? 404 : 400
               else 400
               end
      { status: status, json: { "ok" => false, "reason" => err.reason, "because" => err.because } }
    end
  end
end
