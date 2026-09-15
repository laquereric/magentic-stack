# frozen_string_literal: true

module Vv
  module Perch
    # Hosts run the engine's migrations. No isolate_namespace: table names
    # are perch_* via Record.table_name_prefix.
    class Engine < ::Rails::Engine
    end
  end
end
