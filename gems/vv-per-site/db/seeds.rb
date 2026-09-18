# frozen_string_literal: true

# Rails entry point. A host app that mounts this engine can:
#
#   Vv::PerSite::Engine.load_seed
#   # or, from db/seeds.rb: load the engine seeds
#
# SIC (no Rails host) uses: rake vv_per_site:okf:load SEED=data/seed/docs

require "vv-per-site"

seed_root = ENV["SEED"] || File.expand_path("../data/seed/docs", __dir__)
result = Vv::PerSite.load_seed(seed_root: seed_root)
unless result[:ok]
  warn "vv-per-site db/seeds.rb: #{result[:reason]} — #{result[:because]}"
  raise result[:because].to_s if defined?(Rails::Application)
end
puts result.inspect if result[:ok]
