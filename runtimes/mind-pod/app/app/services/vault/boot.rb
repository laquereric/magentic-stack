# frozen_string_literal: true

require "json"

module Vault
  # Fail closed at boot. A vault container without caller tokens or a master
  # key must not start. SECRET_KEY_BASE may not fall through to the pod default
  # "mind-pod-not-a-secret" (ADR 0046 names that anti-pattern).
  module Boot
    POD_DEFAULT_SECRET = "mind-pod-not-a-secret"

    class Error < StandardError
      attr_reader :reason, :because
      def initialize(reason, because)
        @reason = reason
        @because = because
        super(reason)
      end
    end

    def self.required!(env = ENV)
      missing = []
      missing << "VAULT_CALLERS" if env["VAULT_CALLERS"].to_s.strip.empty?
      missing << "VAULT_MASTER_KEY" if env["VAULT_MASTER_KEY"].to_s.strip.empty?
      missing << "VAULT_STORE_PATH" if env["VAULT_STORE_PATH"].to_s.strip.empty?
      secret = env["SECRET_KEY_BASE"].to_s
      missing << "SECRET_KEY_BASE" if secret.empty? || secret == POD_DEFAULT_SECRET
      unless missing.empty?
        raise Error.new("vault_boot_refused", { "missing" => missing })
      end
      Vault::Allowlist.parse!(env["VAULT_CALLERS"])
      true
    end

    def self.abort_if_vault!(role, env = ENV)
      return unless role.to_s == "vault"
      required!(env)
    rescue Error, Vault::Allowlist::Unparseable => e
      warn(JSON.generate({ "ok" => false, "reason" => e.reason, "because" => e.because }))
      exit!(1)
    end
  end
end
