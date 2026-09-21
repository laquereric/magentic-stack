# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"

module Vv
  module CpcpHarness
    # Receipt stores for native PUSH tools (design §7.1).
    #
    # A repeated `operationId` returns the first result; the handler does
    # not run again. The receipt must outlive the process that issued it,
    # so a memory store is explicitly not durable and says so rather than
    # letting an id read like a guarantee it is not making. A store that
    # cannot be read is treated as "not cached": the effect proceeds,
    # because a broken cache must not take the tool down.
    module Receipts
      Hit = Struct.new(:hit, :envelope, :warning, keyword_init: true) do
        def hit? = hit == true
      end

      # Shared serialization: envelopes are symbol-keyed Ruby hashes on
      # the way in and out, JSON on disk.
      module Coding
        SYMBOL_VALUES = %i[reason failure_layer face].freeze

        module_function

        def dump(envelope)
          JSON.generate(envelope.transform_keys(&:to_s))
        end

        def load(raw)
          parsed = JSON.parse(raw)
          parsed.each_with_object({}) do |(k, v), h|
            key = k.to_sym
            h[key] = SYMBOL_VALUES.include?(key) && v.is_a?(String) ? v.to_sym : v
          end
        end

        def key(iri, operation_id)
          "#{Digest::SHA256.hexdigest(iri.to_s)[0, 16]}-#{Digest::SHA256.hexdigest(operation_id.to_s)}"
        end
      end

      # The default for a deployment that makes a replay promise.
      class FileStore
        def initialize(dir)
          @dir = dir
        end

        def durable?
          true
        end

        def fetch(iri, operation_id)
          path = path_for(iri, operation_id)
          return Hit.new(hit: false) unless File.exist?(path)

          Hit.new(hit: true, envelope: Coding.load(File.read(path)))
        rescue StandardError
          Hit.new(hit: false, warning: :idempotency_store_unavailable)
        end

        def store(iri, operation_id, envelope)
          FileUtils.mkdir_p(@dir)
          File.write(path_for(iri, operation_id), Coding.dump(envelope))
          nil
        rescue StandardError
          :idempotency_store_unavailable
        end

        private

        def path_for(iri, operation_id)
          File.join(@dir, "#{Coding.key(iri, operation_id)}.json")
        end
      end

      # Useful in a test, and honest in a deployment that has not set up
      # a durable store: every result carries `idempotency_not_durable`.
      class MemoryStore
        def initialize
          @receipts = {}
        end

        def durable?
          false
        end

        def fetch(iri, operation_id)
          key = Coding.key(iri, operation_id)
          return Hit.new(hit: false, warning: :idempotency_not_durable) unless @receipts.key?(key)

          Hit.new(hit: true, envelope: @receipts[key], warning: :idempotency_not_durable)
        end

        def store(iri, operation_id, envelope)
          @receipts[Coding.key(iri, operation_id)] = envelope
          :idempotency_not_durable
        end
      end

      # No store at all. A native PUSH tool running against this one makes
      # no replay promise and says so on every result.
      class NullStore
        def durable?
          false
        end

        def fetch(_iri, _operation_id)
          Hit.new(hit: false, warning: :idempotency_not_durable)
        end

        def store(_iri, _operation_id, _envelope)
          :idempotency_not_durable
        end
      end

      WARNINGS = {
        idempotency_not_durable:
          "This tool's receipt store does not outlive the process, so a repeated operationId " \
          "may perform the write again.",
        idempotency_store_unavailable:
          "This tool's receipt store could not be read, so the effect proceeded without a " \
          "replay check."
      }.freeze
    end
  end
end
