# frozen_string_literal: true

namespace :p10 do
  desc "P10.M1 demo: print deterministic P10 projection CIDs for Mission, Persona, Journey"
  task project: :environment do
    puts "=== P10.M1 canonical projection CIDs ==="
    RailsOsiLevel8::Intent::Projection.print_demo!
    forbidden = ActiveRecord::Base.connection.tables.grep(/intent_mission|intent_persona|intent_journey|intent_flow|intent_grounding|intent_trace/)
    puts "forbidden tables present: #{forbidden.empty? ? 'none' : forbidden.inspect}"
  end
end
