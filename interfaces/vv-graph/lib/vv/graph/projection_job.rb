# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv; end

module Vv::Graph
  # Durable projection outbox row (ADR StorableBootSafe S2).
  #
  # Identity + generation only for project jobs (no serialized triples).
  # Retract jobs may also stash primary_subject_iri + graph_iri so a
  # post-crash drain can still tombstone after the AR row is gone.
  #
  # UNIQUE (ref_type, ref_id) — coalesce by identity; keep latest generation.
  class ProjectionJob < ::ActiveRecord::Base
    self.table_name = "vv_graph_projection_jobs"

    ACTIONS = %w[project retract].freeze
    STATES  = %w[pending applied].freeze

    validates :ref_type, :ref_id, :generation, presence: true
    validates :action, inclusion: { in: ACTIONS }
    validates :state,  inclusion: { in: STATES }

    scope :pending_drain, -> {
      where(state: "pending")
        .or(where("applied_generation IS NULL OR generation > applied_generation"))
    }

    class << self
      def available?
        return false unless defined?(::ActiveRecord::Base)
        return false unless ::ActiveRecord::Base.connected?

        connection.data_source_exists?(table_name)
      rescue StandardError
        false
      end

      # Idempotent schema install for specs and soft host boot.
      def ensure_schema!
        return true if available?

        connection.create_table(table_name) do |t|
          t.string  :ref_type,            null: false
          t.string  :ref_id,              null: false
          t.integer :generation,          null: false, default: 0
          t.string  :action,              null: false, default: "project"
          t.string  :state,               null: false, default: "pending"
          t.integer :applied_generation
          t.integer :projection_version,  null: false, default: 1
          t.string  :primary_subject_iri
          t.string  :graph_iri
          t.timestamps
        end
        connection.add_index(
          table_name,
          %i[ref_type ref_id],
          unique: true,
          name: "index_vv_graph_projection_jobs_on_ref",
        )
        true
      rescue StandardError
        false
      end

      # Upsert by identity. Higher (or equal) generation wins; retract
      # always marks pending so a delete is not coalesced away.
      def enqueue!(ref:, generation:, action: "project",
                   primary_subject_iri: nil, graph_iri: nil,
                   projection_version: 1)
        ensure_schema! unless available?

        action_s = action.to_s
        gen      = Integer(generation)

        job = find_or_initialize_by(ref_type: ref.type, ref_id: ref.id.to_s)
        if job.new_record? ||
           action_s == "retract" ||
           gen >= Integer(job.generation || 0)
          job.generation         = gen
          job.action             = action_s
          job.state              = "pending"
          job.projection_version = Integer(projection_version)
          job.primary_subject_iri = primary_subject_iri if primary_subject_iri
          job.graph_iri           = graph_iri if graph_iri
          job.save!
        end
        job
      end
    end

    def needs_drain?
      state == "pending" ||
        applied_generation.nil? ||
        Integer(generation) > Integer(applied_generation)
    end

    def mark_applied!
      update!(applied_generation: generation, state: "applied")
    end

    def to_ref
      ::Vv::Graph::Ref.new(ref_type, cast_ref_id)
    end

    def cast_ref_id
      # Prefer integer ids when the stored form is all digits.
      return ref_id.to_i if ref_id.to_s.match?(/\A\d+\z/)

      ref_id
    end
  end
end
