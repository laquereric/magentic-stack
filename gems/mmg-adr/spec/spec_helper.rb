# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "mmg-adr"

require "active_record"
require "mmg/adr/vocabulary"
require_relative "../app/models/mmg/adr/record"
require_relative "../app/services/mmg/adr/ingest"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
Mmg::Adr::Record.schema_sql.split(";").map(&:strip).reject(&:empty?).each do |stmt|
  ActiveRecord::Base.connection.execute(stmt)
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.order = :random
  c.around { |ex| ActiveRecord::Base.transaction { ex.run; raise ActiveRecord::Rollback } }
end
