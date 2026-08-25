# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8AuthorizationEvidences < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_authorization_evidences do |t|
      governed_columns(t)
      t.string   :operation_request_cid
      t.string   :principal_iri,           null: false
      t.string   :action,                  null: false
      t.string   :resource_cid
      t.string   :resource_iri
      t.string   :policy_ref,              null: false
      t.string   :decision,                null: false
      t.datetime :decided_at,              null: false
      t.string   :evidence_digest,         null: false
      t.json     :redacted_evidence_json,  null: false, default: {}
      t.json     :evaluator_detail_json,   null: false, default: {}
    end
    governed_indexes(:osi_l8_authorization_evidences)
    add_index :osi_l8_authorization_evidences, [:principal_iri, :action, :decided_at],
              name: "idx_osi_l8_authz_principal_action_time"
    add_index :osi_l8_authorization_evidences, :operation_request_cid
    add_index :osi_l8_authorization_evidences, :policy_ref
    add_index :osi_l8_authorization_evidences, :decision
  end
end
