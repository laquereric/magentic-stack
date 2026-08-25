# frozen_string_literal: true

module Vv
  module Base
    # Hosts run the engine's migrations. No isolate_namespace: table names
    # stay actors/journeys/... so existing mind-pod databases keep working.
    class Engine < ::Rails::Engine
      rake_tasks do
        # db:migrate picks up db/migrate from this gem automatically.
      end
    end
  end
end
