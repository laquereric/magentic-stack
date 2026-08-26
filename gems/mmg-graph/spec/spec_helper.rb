# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_record"
require "mmg-graph"
require_relative "../app/models/mmg/graph/entry"
require_relative "../app/services/mmg/graph/execute"
require_relative "../lib/mmg/graph/cpcp"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
Mmg::Graph::Entry.schema_sql.split(";").map(&:strip).reject(&:empty?).each do |stmt|
  ActiveRecord::Base.connection.execute(stmt)
end

# A CLOSED PORT, on purpose.
#
# These specs must never reach a real Oxigraph. A suite that needs a live store
# is a suite that gets skipped, and the refusals this gem is built on happen
# BEFORE any HTTP call -- so pointing at a dead endpoint both keeps the suite
# hermetic and lets the never-raise property be tested for real rather than
# stubbed into existence.
ENV["MM_OXIGRAPH_URL"] = "http://127.0.0.1:9"

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.order = :random
  c.around { |ex| ActiveRecord::Base.transaction { ex.run; raise ActiveRecord::Rollback } }
end
