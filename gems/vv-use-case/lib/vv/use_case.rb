# frozen_string_literal: true

require_relative "use_case/version"
require_relative "use_case/model"
require_relative "use_case/map"
require_relative "use_case/share"
require_relative "use_case/cpcp"
require_relative "use_case/assets"

module Vv
  # Use-Case 3.0 Essentials on a Fabric board. Overlay consumes this gem.
  # Soft-depends on vv-miro. Does not depend on vv-perch.
  module UseCase
    class << self
      attr_accessor :blob_get, :miro_client

      def reset!
        self.blob_get = nil
        self.miro_client = nil
      end
    end
  end
end
