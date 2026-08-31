# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv; end

module Vv::Graph
  module Publisher
    # Server publisher (S1+S2): durable outbox upsert then drain-now.
    #
    # S2: schedule upserts ProjectionJob (identity+generation), then
    # Immediate drains: atomic-replace project or primary-subject tombstone.
    # applied_generation gate makes re-drain a no-op. never-raise.
    class Immediate
      include Publisher

      # @param ref [Vv::Graph::Ref]
      # @param generation [Integer]
      # @param action [Symbol,String] :project | :retract
      # @param record [ActiveRecord::Base,nil] in-memory row (needed for
      #   retract subject IRIs while attrs still live after_destroy)
      # @return [Symbol] :applied | :skipped | :missing | :no_declaration | :error | :deferred
      def schedule(ref:, generation:, action: :project, record: nil)
        action_s = action.to_s
        subject_iri, graph_iri = capture_subject_context(record)

        job = nil
        if outbox_ready?
          job = ::Vv::Graph::ProjectionJob.enqueue!(
            ref: ref,
            generation: generation,
            action: action_s,
            primary_subject_iri: subject_iri,
            graph_iri: graph_iri,
          )
        end

        drain_job!(job, ref: ref, generation: generation, action: action_s, record: record)
      rescue StandardError
        # never-raise at the Storable boundary. ADR 0054: observe the :error.
        observe_refusal("projection_error", "Publisher::Immediate#schedule", "vv-graph/publisher",
          restoration: {
            "state_reached" => "application row committed; projection schedule raised",
            "inconsistency" => "GRAPH/outbox may not match the committed row",
            "restore_when" => "drain applies a projection job for this ref",
            "restore_action" => "replay or drain pending projection jobs"
          })
        :error
      end

      # Sweep pending / lagging jobs (at-least-once recovery).
      # @return [Hash] { ok:, drained:, skipped:, errors: }
      def drain_pending!
        return { ok: true, drained: 0, skipped: 0, errors: 0 } unless outbox_ready?

        drained = skipped = errors = 0
        ::Vv::Graph::ProjectionJob.pending_drain.find_each do |job|
          status = drain_job!(job)
          case status
          when :applied then drained += 1
          when :skipped then skipped += 1
          else errors += 1
          end
        rescue StandardError
          errors += 1
        end
        if errors > 0
          observe_refusal("drain_pending_errors", "errors=#{errors}", "vv-graph/publisher",
            restoration: {
              "state_reached" => "drain finished with #{errors} job error(s)",
              "inconsistency" => "some projection jobs remain unapplied",
              "restore_when" => "drain reports errors=0",
              "restore_action" => "re-run drain_pending! after GRAPH is reachable"
            })
        end
        { ok: true, drained: drained, skipped: skipped, errors: errors }
      rescue StandardError
        observe_refusal("drain_pending_failed", "Publisher::Immediate#drain_pending!", "vv-graph/publisher",
          restoration: {
            "state_reached" => "drain aborted before a complete pass",
            "inconsistency" => "pending projection jobs vs GRAPH is unknown",
            "restore_when" => "a subsequent drain completes",
            "restore_action" => "re-run drain_pending!"
          })
        { ok: false, drained: 0, skipped: 0, errors: 1 }
      end

      private

      def outbox_ready?
        return false unless defined?(::Vv::Graph::ProjectionJob)
        return true if ::Vv::Graph::ProjectionJob.available?

        ::Vv::Graph::ProjectionJob.ensure_schema!
      rescue StandardError
        false
      end

      def drain_job!(job, ref: nil, generation: nil, action: nil, record: nil)
        ref        ||= job&.to_ref
        generation ||= job&.generation
        action     ||= job&.action || "project"
        generation   = Integer(generation || 0)

        # Idempotent coalesce: already applied this generation.
        if job && !job.needs_drain?
          return :skipped
        end
        if job && !job.applied_generation.nil? &&
           Integer(job.applied_generation) >= generation &&
           job.action == action.to_s
          return :skipped
        end

        status =
          if action.to_s == "retract"
            drain_retract(ref: ref, record: record, job: job)
          else
            drain_project(ref: ref, record: record)
          end

        job.mark_applied! if job && status == :applied
        status
      end

      def drain_project(ref:, record:)
        row = record || ref.resolve
        return :missing if row.nil?
        return :no_declaration unless row.respond_to?(:semantica_emit_triples!)

        result = row.semantica_emit_triples!
        result == false ? :no_declaration : :applied
      end

      def drain_retract(ref:, record:, job:)
        row = record || ref&.resolve
        if row && row.respond_to?(:semantica_retract_primary_subject!)
          row.semantica_retract_primary_subject!
          return :applied
        end

        # Post-crash: row gone; use stashed subject context if present.
        subject = job&.primary_subject_iri
        graph   = job&.graph_iri
        if subject
          ::Vv::Graph::Storable.clear_subject_iri!(subject, graph)
          return :applied
        end

        :missing
      end

      def observe_refusal(reason, because, source, restoration: nil)
        return unless defined?(::RailsCpcp::RefusalLog)
        ::RailsCpcp::RefusalLog.record(reason: reason, because: because, source: source,
                                       restoration: restoration)
      rescue StandardError
        nil
      end

      def capture_subject_context(record)
        return [nil, nil] unless record
        return [nil, nil] unless record.respond_to?(:semantica_primary_subject_iri)

        [record.semantica_primary_subject_iri, record.semantica_graph_iri]
      rescue StandardError
        [nil, nil]
      end
    end
  end
end
