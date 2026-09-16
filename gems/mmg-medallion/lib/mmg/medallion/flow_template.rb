# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "result"
require_relative "vocab"

module Mmg
  module Medallion
    # Reusable Bronze → Silver → Gold contract with stage stamps (design §3).
    class FlowTemplate
      STAGES = %w[bronze silver gold].freeze

      attr_reader :key, :stamps_by_stage

      def initialize(key:, stamps_by_stage:)
        @key = key.to_s.freeze
        @stamps_by_stage = stamps_by_stage.transform_keys(&:to_s).transform_values { |v|
          Array(v).map { |s| s.is_a?(Hash) ? s.transform_keys(&:to_s).freeze : s }.freeze
        }.freeze
      end

      def iri
        Vocab.template(key)
      end

      def stamps_for(stage)
        stamps_by_stage.fetch(stage.to_s, [])
      end

      def to_h
        { key: key, iri: iri, stamps_by_stage: stamps_by_stage, stages: STAGES.dup }
      end

      def self.build(key, &block)
        Builder.new(key: key).tap { |b| b.instance_eval(&block) if block }.build
      end

      class Builder
        def initialize(key:)
          @key = key
          @stamps_by_stage = {}
          @error = nil
        end

        def bronze(&block) = stage("bronze", &block)
        def silver(&block) = stage("silver", &block)
        def gold(&block)   = stage("gold", &block)

        def build
          return @error if @error

          missing = STAGES - @stamps_by_stage.keys
          if missing.any?
            return Result.failure(:invalid_flow_template, "missing stages: #{missing.join(', ')}")
          end

          tpl = FlowTemplate.new(key: @key, stamps_by_stage: @stamps_by_stage)
          Result.success(template: tpl, key: tpl.key, iri: tpl.iri, stamps_by_stage: tpl.stamps_by_stage)
        end

        private

        def stage(name, &block)
          return @error if @error

          if @stamps_by_stage.key?(name)
            @error = Result.failure(:duplicate_stage, "#{name} may be declared once")
            return @error
          end

          collector = StampCollector.new
          collector.instance_eval(&block) if block
          @stamps_by_stage[name] = collector.stamps
          Result.success(stage: name, stamps: collector.stamps)
        end
      end

      class StampCollector
        attr_reader :stamps

        def initialize
          @stamps = []
        end

        def stamp(**pairs)
          pairs.each { |key, value| @stamps << { "key" => key.to_s, "value" => value.to_s }.freeze }
          Result.success(stamps: @stamps)
        end
      end
    end
  end
end
