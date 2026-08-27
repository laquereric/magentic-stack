# frozen_string_literal: true

# Level 8 engine wiring (Milestone 0). No new route — /_cpcp remains the only seam.
RailsOsiLevel8.configure do |config|
  config.role = ENV.fetch("ROLE", "back")
  config.cpcp_path = "/_cpcp/rpc"
  # The gem is INSTALLED (built from gems/ into the base image GEM_HOME), not
  # vendored -- see app/Gemfile: "no path:, no git:, no bin/prepare vendoring
  # step". Engine.root resolves wherever it actually lives; Rails.root.join
  # named a vendor/ tree that app/bin/prepare used to create and no longer
  # exists, so ProfileCatalog.default was being handed a path to nothing.
  config.shape_root = RailsOsiLevel8::Engine.root.join("data/osi-level-8")
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
