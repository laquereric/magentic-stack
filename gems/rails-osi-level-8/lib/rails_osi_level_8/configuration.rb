# frozen_string_literal: true

module RailsOsiLevel8
  # POC configuration. Role-aware: BACK owns models/migrations/adapter;
  # FRONT never loads the AR repository path.
  class Configuration
    attr_accessor :role, :cpcp_path, :shape_root, :profile_catalog,
                  :public_ledgers, :private_ledger, :clock,
                  :base_iri, :profile, :shapes_path, :cid_iri

    def initialize
      @role            = ENV.fetch("ROLE", "back")
      @cpcp_path       = "/_cpcp/rpc"
      @shape_root      = nil # set from initializer / engine root
      @profile_catalog = nil
      @public_ledgers  = %w[canonical sync_intent].freeze
      @private_ledger  = "private_local"
      @clock           = -> { Time.now.utc }
      @base_iri        = ENV.fetch("OSI8_BASE_IRI", "https://osi-level-8.local")
      @profile         = ENV.fetch("OSI8_PROFILE", "1")
      @shapes_path     = ENV["OSI8_SHAPES_PATH"]
      @cid_iri         = ENV["OSI8_CID_IRI"]
    end

    def back? = role.to_s == "back"
    def front? = role.to_s == "front"
  end

  class << self
    def config = (@config ||= Configuration.new)
    def configure
      yield config
    end
  end
end

# Brief alias used throughout RAILS_OSI_LEVEL_8_IN_DEMO.md
OsiLevel8 = RailsOsiLevel8 unless defined?(OsiLevel8)
