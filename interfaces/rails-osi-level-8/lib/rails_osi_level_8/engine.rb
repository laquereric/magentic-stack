# frozen_string_literal: true
require "rails/engine"
module RailsOsiLevel8
  # Additive Rails engine. Mounted in the BACK app ALONGSIDE rails-cpcp; it adds the OSI
  # Level 8 semantic layer, not a competing RPC surface.
  class Engine < ::Rails::Engine
    isolate_namespace RailsOsiLevel8
  end
end
