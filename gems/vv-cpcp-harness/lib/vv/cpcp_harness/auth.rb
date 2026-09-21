# frozen_string_literal: true

module Vv
  module CpcpHarness
    # The *other* credential (design §10.1).
    #
    # Everything else in this gem concerns the Bearer token a deployment
    # issues for a seam. This class concerns the one that pays for the
    # model, which belongs to a person or an organization rather than to
    # the deployment, and whose permitted kinds depend on the backend.
    #
    # The harness never holds a Claude subscription token. It records
    # which *kind* of credential a backend used and, where the source is
    # knowable, where that credential came from — never the value. A
    # credential that is never held cannot be intermediated, which is the
    # simplest way to stay clear of the rule against third parties
    # collecting, storing or intermediating Claude credentials.
    class Auth
      # `client` is the MCP road: the caller brings its own model and its
      # own credential, and this process sees neither. It is a real
      # answer to "which credential", and a weaker answer to "whose
      # account" — the journal says so rather than implying otherwise.
      MODES = %i[api_key cloud subscription client].freeze

      # Advisory only. The backend is authoritative about what it actually
      # used; this table exists so a preflight can say "an API key is set
      # in this environment and will outrank your plan", which is the
      # mistake that bills a key for weeks unnoticed.
      ENV_HINTS = {
        api_key: %w[ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN],
        cloud: %w[CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY]
      }.freeze

      attr_reader :mode, :source, :backend

      def initialize(mode:, source: nil, backend: nil)
        @mode = mode.to_s.to_sym
        @source = source
        @backend = backend
      end

      def subscription?
        @mode == :subscription
      end

      def known?
        MODES.include?(@mode)
      end

      # A shared or scheduled run — CI, a nightly suite, anything
      # triggered on someone else's behalf — must carry an API key or a
      # cloud credential, and fails closed without one. Only an
      # individual's local, interactive run may fall back to whatever
      # their own login is.
      def check(shared: false)
        unless known?
          return Envelope.refuse(:auth_mode_not_permitted,
                                 "unknown auth mode #{@mode.inspect}; expected one of #{MODES.join(", ")}")
        end
        return nil unless shared && subscription?

        Envelope.refuse(
          :auth_mode_not_permitted,
          "a shared or scheduled run may not authenticate by subscription#{backend ? " (#{backend})" : ""}; " \
          "use an API key or a cloud provider credential, or serve these tools over MCP and let " \
          "the calling client authenticate for itself"
        )
      end

      # Whether the harness can say which account paid. Over MCP it
      # cannot: the client holds the credential, and an attribution that
      # claimed otherwise would be a guess wearing a record's clothes.
      def attests_account?
        @mode != :client
      end

      def to_h
        { "mode" => @mode.to_s, "source" => @source, "backend" => @backend }.compact
      end

      # One line for the preflight report. Never the value.
      def describe
        where = @source ? " from #{@source}" : ""
        "#{@backend || "backend"}: #{@mode}#{where}"
      end

      class << self
        def api_key(source: nil, backend: nil)
          new(mode: :api_key, source: source, backend: backend)
        end

        def cloud(source: nil, backend: nil)
          new(mode: :cloud, source: source, backend: backend)
        end

        # Declared, not held: the harness records that a backend signed in
        # through Anthropic's own flow and stores nothing about it.
        def subscription(backend: nil)
          new(mode: :subscription, source: "the backend's own login", backend: backend)
        end

        # The MCP road. The calling client authenticates for itself, so
        # there is nothing here to hold, report or intermediate.
        def client_side(backend: "mcp")
          new(mode: :client, source: "the calling MCP client", backend: backend)
        end

        # What this environment implies, for the preflight report. An API
        # key present in the environment outranks a plan login in most
        # backends, so it is named first and named loudly.
        def env_hints(env = ENV)
          ENV_HINTS.flat_map do |mode, names|
            names.select { |name| !env[name].to_s.empty? }
                 .map { |name| { mode: mode, source: "env:#{name}" } }
          end
        end
      end
    end
  end
end
