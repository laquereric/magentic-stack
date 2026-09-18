# frozen_string_literal: true

require_relative "per_site/version"
require_relative "per_site/record"
require_relative "per_site/okf_node"
require_relative "per_site/site"
require_relative "per_site/cta"
require_relative "per_site/guide"
require_relative "per_site/cpcp"
require_relative "per_site/okf/parser"
require_relative "per_site/okf/tree"
require_relative "per_site/okf/importer"
require_relative "per_site/okf/seeder"
require_relative "per_site/migrator"
require_relative "per_site/boot"
require_relative "per_site/engine" if defined?(Rails::Engine)

module Vv
  module PerSite
    # Convert an OKF docs/ tree into data/seed/docs YAML (Rails seed shape)
    # and/or load it into the hierarchical AR table.
    def self.sync(docs_root:, seed_root:, bundle_key: nil)
      Okf::Seeder.sync(docs_root, seed_root, bundle_key: bundle_key)
    end

    def self.import(docs_root:, bundle_key: nil)
      Okf::Importer.import(docs_root, bundle_key: bundle_key)
    end

    def self.load_seed(seed_root:)
      Okf::Seeder.load!(seed_root)
    end

    def self.boot_standalone!(database: nil)
      Boot.standalone!(database: database)
    end
  end
end
