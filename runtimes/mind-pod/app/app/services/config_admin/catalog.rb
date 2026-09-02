# frozen_string_literal: true

require "json"

module ConfigAdmin
  # Vendor/model/price/tools table. ROLE=config owns it (row 15).
  # No credential. No egress. Discovery and verify stay on switch.
  class Catalog
    PATH = "config/llm_catalog.json"
    VENDORS = %w[ollama openai anthropic fireworks openrouter nvidia].freeze

    def self.path
      Rails.root.join(PATH)
    end

    def self.load
      new(JSON.parse(File.read(path)))
    end

    def initialize(data)
      @data = data
    end

    def vendors
      @data.fetch("vendors")
    end

    def why
      @data["why"] || {}
    end

    def owned_by
      @data["owned_by"]
    end
  end
end
