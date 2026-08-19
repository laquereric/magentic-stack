# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8BiographyEvents < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_biography_events do |t|
      governed_columns(t)
      t.string   :subject_iri,     null: false
      t.string   :event_kind,      null: false
      t.string   :asserted_by_iri, null: false
      t.datetime :valid_from
      t.datetime :valid_to
      t.json     :statement_json,  null: false
    end
    governed_indexes(:osi_l8_biography_events)
    add_index :osi_l8_biography_events, [:subject_iri, :recorded_at], name: "idx_osi_l8_bio_subject_time"
    add_index :osi_l8_biography_events, :asserted_by_iri
    add_index :osi_l8_biography_events, :event_kind
  end
end
