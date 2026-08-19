# frozen_string_literal: true

# Level 8 engine wiring (Milestone 0). No new route — /_cpcp remains the only seam.
RailsOsiLevel8.configure do |config|
  config.role = ENV.fetch("ROLE", "back")
  config.cpcp_path = "/_cpcp/rpc"
  config.shape_root = Rails.root.join("vendor/rails-osi-level-8/data/osi-level-8")
  config.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(config.shape_root)
  config.public_ledgers = %w[canonical sync_intent].freeze
  config.private_ledger = "private_local"
  config.clock = -> { Time.current }
  config.base_iri = ENV.fetch("OSI8_BASE_IRI", ENV.fetch("BASE_IRI", "https://mind-pod.local"))
end

Rails.application.config.to_prepare do
  # Register the decorator only in the HTTP writer. FRONT receives no AR repository.
  RailsOsiLevel8::CpcpAdapter.install!(RailsCpcp) if ENV.fetch("ROLE", "back") == "back"
end
