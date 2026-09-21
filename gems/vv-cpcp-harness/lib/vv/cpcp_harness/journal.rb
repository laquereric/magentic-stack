# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module Vv
  module CpcpHarness
    # "On whose word."
    #
    # The seam keeps the authoritative record of what happened. What the
    # seam cannot know is which agent session, model and human stood
    # behind a given `operationId`. The harness records that link, one
    # append-only line per PUSH, and the `operationId` joins the two
    # records without adding a field to the wire.
    class Journal
      attr_reader :entries

      # `sink` receives each entry hash (ship it to a log store); `path`
      # appends JSONL locally. Both may be set; neither is required, in
      # which case entries are kept in memory for tests.
      def initialize(path: nil, sink: nil, clock: nil, pull_sample: 10)
        @path = path
        @sink = sink
        @clock = clock || -> { Time.now.utc }
        @pull_sample = pull_sample.to_i
        @pulls = 0
        @entries = []
      end

      # Every PUSH is journaled in full, whether it reached a seam or ran
      # in-process, and whether it succeeded or was refused.
      def push(tool:, envelope:, operation_id:, operation_id_source:, context: nil, approved_by: nil)
        write(
          "at" => @clock.call.iso8601(3),
          "iri" => tool.iri,
          "seam" => tool.seam,
          "tool" => tool.name,
          "operationId" => operation_id,
          "operationIdSource" => operation_id_source.to_s,
          "rpcId" => context&.rpc_id,
          "backend" => context&.backend,
          # Which kind of credential paid for the call, never the
          # credential itself (design §10.1).
          "authMode" => auth_mode(context),
          "model" => context&.model,
          "sessionId" => context&.session_id,
          "agent" => context&.agent,
          "approvedBy" => approved_by || context&.approved_by,
          "outcome" => outcome(envelope),
          "cidDigest" => cid_digest(tool)
        )
      end

      # A read promises nothing, so it is journaled at a lower level of
      # detail and sampled.
      def pull(tool:, envelope:, context: nil)
        @pulls += 1
        return nil if @pull_sample <= 0
        return nil unless (@pulls % @pull_sample).zero?

        write(
          "at" => @clock.call.iso8601(3),
          "iri" => tool.iri,
          "seam" => tool.seam,
          "tool" => tool.name,
          "sessionId" => context&.session_id,
          "outcome" => outcome(envelope)
        )
      end

      private

      # Accepts an Auth, a symbol, or nothing.
      def auth_mode(context)
        mode = context&.auth_mode
        return nil if mode.nil?

        mode.respond_to?(:mode) ? mode.mode.to_s : mode.to_s
      end

      def cid_digest(tool)
        cid = tool.cpcp&.cid
        return nil unless cid.is_a?(Hash)

        cid["digest"] || cid[:digest]
      end

      def outcome(envelope)
        {
          "ok" => envelope[:ok] == true,
          "http" => envelope[:http_status],
          "reason" => envelope[:reason]&.to_s,
          "liveApplied" => envelope[:live_applied]
        }.reject { |_, v| v.nil? }
      end

      def write(entry)
        entry = entry.reject { |_, v| v.nil? }
        @entries << entry
        @sink&.call(entry)
        append(entry) if @path
        entry
      rescue StandardError
        # A journal that cannot be written must not take the call down;
        # the seam's own record still exists, and the gap is visible.
        entry
      end

      def append(entry)
        FileUtils.mkdir_p(File.dirname(@path))
        File.open(@path, "a") do |f|
          f.flock(File::LOCK_EX)
          f.puts(JSON.generate(entry))
        end
      end
    end
  end
end
