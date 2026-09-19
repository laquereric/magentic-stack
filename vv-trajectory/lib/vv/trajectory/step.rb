# frozen_string_literal: true

require "digest"

module Vv
  module Trajectory
    # One observed step: what was intended, what was called, with what, and what
    # came back.
    #
    # A step is Bronze. It is observed, kept verbatim, and never summarised on
    # ingest. `reasoning` is the model's stated intent at this step and is kept
    # because the gap between stated intent and actual call is a measurable
    # failure -- not because prose is the record.
    #
    # `receipt` is the execution log's own entry for this call. A step that
    # claims a call with no receipt is a fabricated execution, which is the most
    # dangerous failure type there is: everything after it reasons over invented
    # data.
    class Step
      attr_reader :index, :tool, :args, :reasoning, :result, :receipt, :kind

      def initialize(index:, tool:, args: {}, reasoning: nil, result: nil,
                     receipt: nil, kind: :tool_call)
        @index = index.to_i
        @tool = tool.to_s
        @args = args || {}
        @reasoning = reasoning
        @result = result
        @receipt = receipt
        @kind = kind.to_sym
      end

      # Identity of the call, not of the prose. Two steps are the same move when
      # they call the same tool with the same arguments; what the model said
      # about it does not enter.
      def call_key = "#{tool}(#{canonical_args})"

      def canonical_args
        args.to_h { |k, v| [k.to_s, v] }.sort.map { |k, v| "#{k}=#{v}" }.join(",")
      end

      def reasoning_key
        return nil if reasoning.to_s.strip.empty?

        Digest::SHA256.hexdigest(reasoning.to_s.strip.downcase.gsub(/\s+/, " "))[0, 16]
      end

      # Every claimed call must have a receipt in the execution log, and the
      # receipt's result must be the one the step reports.
      def receipt_findings
        return [] unless kind == :tool_call

        if receipt.nil?
          return [finding(:fabricated_execution, "step #{index} claims #{tool} with no entry in the log",
                          :critical)]
        end

        logged = receipt[:tool] || receipt["tool"]
        if logged.to_s != tool
          return [finding(:receipt_tool_mismatch,
                          "step #{index} claims #{tool}; the log records #{logged}", :critical)]
        end

        logged_result = receipt.key?(:result) ? receipt[:result] : receipt["result"]
        if result && logged_result && result != logged_result
          return [finding(:fabricated_result,
                          "step #{index} reports a result the log does not carry", :high)]
        end

        []
      end

      def finding(test, text, severity)
        { test: test, finding: text, severity: severity, step: index }
      end

      def to_h
        { index: index, tool: tool, args: args, kind: kind }
      end

      def chars = [tool, canonical_args, reasoning.to_s, result.to_s].join.length
    end
  end
end
