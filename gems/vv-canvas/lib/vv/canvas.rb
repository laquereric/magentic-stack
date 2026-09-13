# frozen_string_literal: true

require_relative "canvas/version"
require_relative "canvas/blob_gate"
require_relative "canvas/boards"
require_relative "canvas/cpcp"
require_relative "canvas/assets"
require_relative "canvas/engine" if defined?(::Rails::Railtie)

module Vv
  # Fabric canvas + digest-named versions. Overlay consumes this gem.
  module Canvas
    class << self
      attr_accessor :board_class

      def board_memory
        @board_memory ||= {}
      end

      def reset!
        @board_memory = {}
        self.board_class = nil
      end
    end
  end
end
