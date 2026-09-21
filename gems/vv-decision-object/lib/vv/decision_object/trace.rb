# frozen_string_literal: true

require "json"
require "time"

module Vv
  module DecisionObject
    # An append-only record of how and why a decision was made: what was
    # asked, of whom, against which state, what came back, which threshold
    # applied, what was committed, and what happened afterwards.
    #
    # The cost of writing decisions down has collapsed, because the system
    # making the decision can now record it. This is that recording. It is
    # append-only on purpose — a trace you can edit is a memo.
    #
    # Time is injected (`clock:`) so traces are reproducible in tests and
    # so a caller can stamp from a database clock rather than the process.
    class Trace
      # Structural keys an entry always owns. A payload may not shadow
      # them — an append-only record whose sequence can be overwritten by
      # a careless keyword is not append-only.
      RESERVED = %i[seq at kind].freeze

      Entry = Struct.new(:seq, :at, :kind, :payload, keyword_init: true) do
        def to_h
          safe = payload.each_with_object({}) do |(k, v), h|
            h[RESERVED.include?(k) ? :"entry_#{k}" : k] = v
          end
          { seq: seq, at: at, kind: kind }.merge(safe)
        end
      end

      attr_reader :entries, :clock

      def initialize(clock: nil)
        @clock = clock || -> { Time.now.utc.iso8601 }
        @entries = []
      end

      def append(kind, **payload)
        entry = Entry.new(seq: @entries.size, at: stamp, kind: kind.to_sym, payload: payload)
        @entries << entry
        entry
      end

      def size
        entries.size
      end

      def empty?
        entries.empty?
      end

      def of_kind(kind)
        entries.select { |e| e.kind == kind.to_sym }
      end

      def last_of(kind)
        of_kind(kind).last
      end

      def to_a
        entries.map(&:to_h)
      end

      def to_json(*args)
        JSON.generate(to_a, *args)
      end

      # An Agent Decision Record: the trace as something a human reviewer
      # (or the next agent to face the same call) can read, committed
      # alongside the code that acted on it.
      def to_markdown(title: "Decision record")
        lines = ["# #{title}", ""]
        entries.each do |entry|
          lines << "## #{entry.seq}. #{entry.kind} — #{entry.at}"
          lines << ""
          entry.payload.each { |k, v| lines << "- **#{k}**: #{render(v)}" }
          lines << ""
        end
        lines.join("\n")
      end

      private

      def stamp
        clock.call
      rescue StandardError
        nil
      end

      def render(value)
        case value
        when Hash then value.map { |k, v| "#{k}=#{render(v)}" }.join(", ")
        when Array then value.map { |v| render(v) }.join(", ")
        when Float then format("%.4g", value)
        when nil then "—"
        else value.to_s
        end
      end
    end
  end
end
