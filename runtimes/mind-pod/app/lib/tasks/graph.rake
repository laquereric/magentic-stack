# frozen_string_literal: true

namespace :graph do
  desc "Re-project every Storable record into GRAPH (whole-store replay)"
  task replay: :environment do
    result = GraphReplay.run
    puts JSON.pretty_generate(result)
    # Non-zero on refusal: a replay that failed must not look like a clean run to
    # whatever called it.
    exit(1) unless result[:ok]
  end
end
