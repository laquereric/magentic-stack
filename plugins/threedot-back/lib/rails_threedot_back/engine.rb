# frozen_string_literal: true
require "rails/engine"
module RailsThreedotBack
  # Additive Rails engine: the threedot BACK (live data plane). It serves the CID(s),
  # operations, and the plugin object model as ActiveRecord rooted at Cid, over the SINGLE
  # public CPCP seam (/_cpcp via rails-cpcp). It does NOT add its own endpoint family.
  class Engine < ::Rails::Engine
    isolate_namespace RailsThreedotBack
    config.autoload_paths << File.expand_path("../../app/models", __dir__)
  end
end
