# frozen_string_literal: true

require "json"
require "digest"

module Vv
  module CpcpHarness
    # A CID describes a seam: a JSON-LD `@context`, an operation manifest
    # (method, IRI, informal params, whether `operationId` is required,
    # result) and closed SHACL shapes.
    #
    # Generation reads a *committed snapshot*, never the live document.
    # The live CID is fetched only to check that the snapshot still
    # describes the seam, which is what pinning means: a participant pins
    # a version and refuses a superseded contract.
    class Cid
      # One entry of the operation manifest.
      Operation = Struct.new(:method_name, :iri, :params, :operation_id, :result, :description,
                             keyword_init: true) do
        def requires_operation_id?
          operation_id.to_s == "required"
        end

        # An operation that explicitly says it wants no id. Silence is
        # not a claim, and is not read as one.
        def forbids_operation_id?
          %w[none forbidden optional].include?(operation_id.to_s)
        end

        def states_operation_id?
          !operation_id.to_s.empty?
        end
      end

      attr_reader :payload, :source

      def initialize(payload, source: nil)
        @payload = payload
        @source = source
      end

      class << self
        # Read a committed snapshot. Never raises: an unreadable snapshot
        # is a refusal like any other.
        def load(path)
          raw = File.read(path)
          from(JSON.parse(raw), source: path)
        rescue Errno::ENOENT
          Envelope.refuse(:cid_unreadable, "no CID snapshot at #{path}")
        rescue JSON::ParserError => e
          Envelope.refuse(:cid_unreadable, "#{path}: #{e.class}: #{e.message}")
        rescue StandardError => e
          Envelope.refuse(:cid_unreadable, "#{path}: #{e.class}: #{e.message}")
        end

        def from(payload, source: nil)
          unless payload.is_a?(Hash)
            return Envelope.refuse(:cid_unreadable, "a CID is a JSON object, got #{payload.class}")
          end

          Envelope.ok(result: new(payload, source: source))
        end

        # Digest over the canonical form, not the bytes: a reformatted
        # snapshot and a reformatted live document still describe the
        # same seam, and a pin that tripped on whitespace would teach
        # operators to ignore it.
        def digest(payload)
          "sha256-#{Digest::SHA256.hexdigest(JSON.generate(canonical(payload)))}"
        end

        def canonical(value)
          case value
          when Hash then value.sort_by { |k, _| k.to_s }.to_h { |k, v| [k.to_s, canonical(v)] }
          when Array then value.map { |v| canonical(v) }
          else value
          end
        end
      end

      def digest
        @digest ||= self.class.digest(@payload)
      end

      def id
        @payload["cid"]
      end

      def kind
        @payload["kind"].to_s
      end

      def description
        @payload["description"].to_s
      end

      def context
        @payload["@context"]
      end

      def shapes
        @payload["shapes"].to_s
      end

      def contract_version
        @payload["contract_version"] || @payload["contractVersion"] || @payload.dig("contract", "version")
      end

      def operations
        @operations ||= Array(@payload["operations"]).map do |op|
          next nil unless op.is_a?(Hash)

          Operation.new(
            method_name: op["method"].to_s,
            iri: op["iri"].to_s,
            params: op["params"],
            operation_id: op["operationId"] || op["operation_id"],
            result: op["result"],
            description: op["description"].to_s
          )
        end.compact
      end

      def operation(method)
        operations.find { |op| op.method_name == method.to_s }
      end

      def methods_published
        operations.map(&:method_name)
      end

      # PUSH when the CID's kind says so, or the operation requires an
      # `operationId`. When the two disagree the answer is a refusal, not
      # a guess: a write described as a read is the one mistake this
      # whole design exists to prevent.
      def face_for(operation)
        by_kind = kind == "push"
        if operation.states_operation_id?
          by_op = operation.requires_operation_id?
          if by_kind != by_op
            return Envelope.refuse(
              :cid_face_conflict,
              "#{operation.method_name}: CID kind is #{kind.inspect} but operationId is " \
              "#{operation.operation_id.inspect}"
            )
          end

          return Envelope.ok(result: by_op ? :push : :pull)
        end

        Envelope.ok(result: by_kind ? :push : :pull)
      end

      # Does a live CID still describe the seam this snapshot pinned?
      # Returns nil when it does, and a sentence when it does not.
      def superseded_by(live, contract_version: nil)
        return "the live CID could not be read" unless live.is_a?(Cid)

        if live.digest != digest
          return "live CID digest #{live.digest} differs from the pinned #{digest}"
        end

        pinned = contract_version || self.contract_version
        return nil if pinned.nil?
        return nil if live.contract_version.nil? && pinned == self.contract_version
        return nil if live.contract_version.to_s == pinned.to_s

        "live contract version #{live.contract_version.inspect} differs from the pinned #{pinned.inspect}"
      end
    end
  end
end
