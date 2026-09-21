# frozen_string_literal: true

require "securerandom"
require "digest"
require "json"

module Vv
  module CpcpHarness
    # A PUSH names its intent before performing it. At an HTTP seam the
    # caller is the only party who can name it, and here the caller is the
    # harness acting for a model — so the harness mints, once per tool
    # call, and returns the id in every result, success or refusal.
    module OperationId
      module_function

      # `note.create` → `note-create-a1b2c3d4e5f60718`
      def mint(method)
        "#{method.to_s.tr(".", "-").tr("_", "-")}-#{SecureRandom.hex(8)}"
      end

      # The model, not the harness, decides whether to try again after a
      # failure — and a second tool call with a reused id but different
      # arguments would silently return the first receipt. The bridge
      # remembers which arguments each id was first used with, so that
      # mistake is caught locally instead of read as a success.
      class Ledger
        def initialize
          @seen = {}
        end

        # Returns nil when the pairing is new or consistent, and a
        # sentence explaining the conflict when it is not.
        def check(operation_id, params)
          return nil if operation_id.to_s.empty?

          digest = self.class.digest(params)
          first = @seen[operation_id]
          if first.nil?
            @seen[operation_id] = digest
            return nil
          end
          return nil if first == digest

          "operationId #{operation_id.inspect} was already used in this session with different " \
            "arguments; reusing it would return the earlier receipt. Omit it for a new write."
        end

        def known?(operation_id)
          @seen.key?(operation_id)
        end

        def self.digest(params)
          Digest::SHA256.hexdigest(JSON.generate(canonical(params)))
        end

        def self.canonical(value)
          case value
          when Hash then value.sort_by { |k, _| k.to_s }.to_h { |k, v| [k.to_s, canonical(v)] }
          when Array then value.map { |v| canonical(v) }
          else value
          end
        end
      end
    end
  end
end
