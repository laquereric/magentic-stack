# frozen_string_literal: true

module Vv
  module CpcpHarness
    # A seam credential: callable, so the transport reads it at call
    # time, and able to say where it came from without ever saying what
    # it is. `present?` touches the value only to ask whether there is
    # one; nothing here ever returns or logs it.
    class Credential
      attr_reader :source

      def initialize(source:, &reader)
        @source = source
        @reader = reader
      end

      def call
        @reader.call
      end

      def present?
        !call.to_s.empty?
      end
    end

    # One seam the harness calls.
    #
    # Two choices here are deliberate. Generation runs from a *committed
    # snapshot*, not from the live CID, so tool definitions are reviewable
    # and builds are reproducible. And `include` is an explicit allowlist:
    # a seam may publish operations the agent should never see, so adding
    # one is a reviewed change — and a change to what the repo manifest
    # says the harness depends on.
    Seam = Struct.new(:name, :endpoint, :cid_snapshot, :cid_payload, :cid_digest,
                      :contract_version, :scope, :credential, :status_profile,
                      :include, :timeout, :pin_ttl, keyword_init: true) do
      def scope_name
        (scope || "dependency").to_s
      end

      def cid_url
        "#{endpoint.to_s.sub(%r{/\z}, "")}/cid.json"
      end
    end

    # The whole bridge: seams, where the journal goes, which receipts
    # store native PUSH tools use, and what the agent is allowed to
    # attempt.
    class Config
      DEFAULTS = {
        name: "cpcp-agent-harness",
        unit: nil,
        contract_repo: "https://github.com/laquereric/coordination-protocol-contract-package",
        contract_rev: nil,
        journal_path: nil,
        journal_sink: nil,
        pull_sample: 10,
        receipts_dir: nil,
        receipts: nil,
        permission_rules: [],
        approver: nil,
        pin_ttl: Client::DEFAULT_PIN_TTL,
        harness_seam: "harness"
      }.freeze

      attr_reader :seams, :options

      def initialize(seams:, **options)
        @seams = seams
        @options = DEFAULTS.merge(options)
      end

      def [](key)
        @options[key]
      end

      def seam(name)
        @seams.find { |s| s.name == name.to_s }
      end

      # Never raises: a malformed configuration is a refusal.
      def self.build(seams: [], **options)
        built = Array(seams).map do |raw|
          seam = raw.is_a?(Seam) ? raw : Seam.new(**raw.transform_keys(&:to_sym))
          seam.name = seam.name.to_s
          if seam.name.empty?
            return Envelope.refuse(:tool_definition_invalid, "every seam needs a name")
          end
          if seam.cid_snapshot.nil? && seam.cid_payload.nil?
            return Envelope.refuse(:cid_unreadable,
                                   "seam #{seam.name} has neither a cid_snapshot path nor a cid_payload")
          end

          seam
        end

        Envelope.ok(result: new(seams: built, **options))
      end
    end
  end
end
