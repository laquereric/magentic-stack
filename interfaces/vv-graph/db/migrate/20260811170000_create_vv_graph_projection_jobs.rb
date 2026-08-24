# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

# S2 (ADR StorableBootSafe) — durable projection outbox.
# Install into the host Rails app (server/db/migrate) or run via
# Vv::Graph::ProjectionJob.ensure_schema! in specs.
class CreateVvGraphProjectionJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :vv_graph_projection_jobs do |t|
      t.string  :ref_type,           null: false
      t.string  :ref_id,             null: false
      t.integer :generation,         null: false, default: 0
      t.string  :action,             null: false, default: "project"
      t.string  :state,              null: false, default: "pending"
      t.integer :applied_generation
      t.integer :projection_version, null: false, default: 1
      t.string  :primary_subject_iri
      t.string  :graph_iri
      t.timestamps
    end

    add_index :vv_graph_projection_jobs,
              %i[ref_type ref_id],
              unique: true,
              name: "index_vv_graph_projection_jobs_on_ref"
  end
end
