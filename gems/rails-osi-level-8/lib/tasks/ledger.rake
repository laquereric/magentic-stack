# frozen_string_literal: true

namespace :ledger do
  desc "Rung 4 report from existing streams; blob named by digest (not a scrape)"
  task report: :environment do
    dir = Rails.root.join("tmp/ledger-reports")
    result = RailsOsiLevel8::LedgerReport.call(dir: dir.to_s)
    puts JSON.pretty_generate(result)
    exit(1) unless result[:ok]
  end
end
