# frozen_string_literal: true

require_relative "concerns/osi_l8_migration_helpers"

class CreateOsiL8CyborgChannels < ActiveRecord::Migration[8.0]
  include OsiL8MigrationHelpers

  def change
    create_table :osi_l8_cyborg_channels do |t|
      governed_columns(t)
      t.string :cyborg_iri,           null: false
      t.string :channel_key,          null: false
      t.string :counterparty_iri
      t.string :direction,            null: false
      t.string :transport,            null: false
      t.string :channel_status,       null: false
      t.string :contract_context_cid
      t.json   :capabilities_json,    null: false, default: {}
    end
    governed_indexes(:osi_l8_cyborg_channels)
    add_index :osi_l8_cyborg_channels, [:cyborg_iri, :channel_key, :payload_digest],
              unique: true, name: "idx_osi_l8_channels_cyborg_key_digest"
    add_index :osi_l8_cyborg_channels, [:cyborg_iri, :recorded_at], name: "idx_osi_l8_channels_cyborg_time"
    add_index :osi_l8_cyborg_channels, :contract_context_cid
  end
end
