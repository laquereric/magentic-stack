# frozen_string_literal: true

require "json"

module ConfigAdmin
  # Fail closed at boot. A published operator UI with no vault URL or
  # caller token must not start. SECRET_KEY_BASE may not fall through to
  # the pod default (ADR 0046 names that anti-pattern).
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
      missing << "VAULT_URL" if env["VAULT_URL"].to_s.strip.empty?
      missing << "VAULT_TOKEN" if env["VAULT_TOKEN"].to_s.strip.empty?
      missing << "PERSIST_URL" if env["PERSIST_URL"].to_s.strip.empty?
      missing << "PERSIST_TOKEN" if env["PERSIST_TOKEN"].to_s.strip.empty?
      secret = env["SECRET_KEY_BASE"].to_s
      missing << "SECRET_KEY_BASE" if secret.empty? || secret == POD_DEFAULT_SECRET
      unless missing.empty?
        raise Error.new("config_boot_refused", { "missing" => missing })
      end
      true
    end

    def self.abort_if_config!(role, env = ENV)
      return unless role.to_s == "config"
      required!(env)
    rescue Error => e
      warn(JSON.generate({ "ok" => false, "reason" => e.reason, "because" => e.because }))
      exit!(1)
    end
  end
end
