# frozen_string_literal: true
module RailsOsiLevel8
  # POC configuration. base_iri grounds @id/@type; profile selects the active OSI Level 8
  # profile (1 Cyborg Channel .. 8 Architectural Learning); shapes_path points at the
  # osi-level-8 profile SHACL shapes used by Grounding.
  class Configuration
    attr_accessor :base_iri, :profile, :shapes_path, :cid_iri
    def initialize
      @base_iri    = ENV.fetch("OSI8_BASE_IRI", "https://osi-level-8.local")
      @profile     = ENV.fetch("OSI8_PROFILE", "1")          # active profile id
      @shapes_path = ENV["OSI8_SHAPES_PATH"]                  # dir of profile-*.ttl (from osi-level-8)
      @cid_iri     = ENV["OSI8_CID_IRI"]                      # pinned CID this deployment conforms to
    end
  end
  class << self
    def config = (@config ||= Configuration.new)
    def configure = (yield config)
  end
end
