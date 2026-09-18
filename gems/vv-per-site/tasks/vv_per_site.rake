# frozen_string_literal: true

# Rake tasks SIC (or any OKF author) runs:
#
#   bundle exec rake vv_per_site:okf:seed     # docs/ → data/seed/docs
#   bundle exec rake vv_per_site:okf:load     # data/seed/docs → AR
#   bundle exec rake vv_per_site:okf:import   # docs/ → AR directly
#   bundle exec rake vv_per_site:okf:sync     # seed then load
#
# ENV:
#   DOCS     source OKF folder (default: ./docs)
#   SEED     seed destination  (default: ./data/seed/docs)
#   BUNDLE   bundle_key override
#   DATABASE_URL  or sqlite at tmp/vv_per_site.sqlite3 when no Rails host

unless Rake::Task.task_defined?(:environment)
  task :environment do
    require "vv-per-site"
    Vv::PerSite.boot_standalone!
  end
end

namespace :vv_per_site do
  namespace :okf do
    def vv_docs_root
      ENV.fetch("DOCS", File.expand_path("docs", Dir.pwd))
    end

    def vv_seed_root
      ENV.fetch("SEED", File.expand_path("data/seed/docs", Dir.pwd))
    end

    def vv_bundle_key
      key = ENV["BUNDLE"].to_s
      key.empty? ? nil : key
    end

    def vv_report(result)
      if result[:ok]
        puts result.inspect
      else
        warn "vv_per_site: #{result[:reason]} — #{result[:because]}"
        exit 1
      end
    end

    desc "Convert an OKF docs/ tree into data/seed/docs YAML (Rails seed shape)"
    task seed: :environment do
      require "vv-per-site"
      vv_report Vv::PerSite::Okf::Seeder.export(vv_docs_root, vv_seed_root, bundle_key: vv_bundle_key)
    end

    desc "Load data/seed/docs YAML into the hierarchical OKF AR table (like db:seed)"
    task load: :environment do
      require "vv-per-site"
      vv_report Vv::PerSite.load_seed(seed_root: vv_seed_root)
    end

    desc "Import an OKF docs/ tree straight into AR, skipping the seed files"
    task import: :environment do
      require "vv-per-site"
      vv_report Vv::PerSite.import(docs_root: vv_docs_root, bundle_key: vv_bundle_key)
    end

    desc "Convert docs/ → data/seed/docs and load the YAML into AR"
    task sync: :environment do
      require "vv-per-site"
      vv_report Vv::PerSite.sync(docs_root: vv_docs_root, seed_root: vv_seed_root, bundle_key: vv_bundle_key)
    end
  end
end
