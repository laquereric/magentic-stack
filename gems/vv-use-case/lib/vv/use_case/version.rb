# frozen_string_literal: true

module Vv
  module UseCase
    VERSION = File.read(File.expand_path("../../../VERSION", __dir__)).strip
    SCHEMA = "sharedai.uc.essentials.v1"
    TO_JSON_KEYS = %w[ucKind ucId ucRole ucFrom ucTo ucStereotype].freeze
  end
end
