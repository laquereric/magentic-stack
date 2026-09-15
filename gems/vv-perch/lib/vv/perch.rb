# frozen_string_literal: true

require_relative "perch/version"
require_relative "perch/envelope"
require_relative "perch/refusals"
require_relative "perch/doctrine"
require_relative "perch/record"
require_relative "perch/use_case"
require_relative "perch/step"
require_relative "perch/slice"
require_relative "perch/slice_step"
require_relative "perch/slice_requirement"
require_relative "perch/outward_signal"
require_relative "perch/signal_reading"
require_relative "perch/wholeness_finding"
require_relative "perch/freeze"
require_relative "perch/freeze_edge"
require_relative "perch/orphan"
require_relative "perch/orphan_party"
require_relative "perch/release_group"
require_relative "perch/effect_binding"
require_relative "perch/slice_method"
require_relative "perch/engine" if defined?(::Rails::Engine)

module Vv
  module Perch
    TABLES = %w[
      perch_use_cases
      perch_steps
      perch_slices
      perch_slice_steps
      perch_slice_requirements
      perch_outward_signals
      perch_signal_readings
      perch_wholeness_findings
      perch_freezes
      perch_freeze_edges
      perch_orphans
      perch_orphan_parties
      perch_release_groups
      perch_effect_bindings
      perch_methods
    ].freeze

    module_function

    def version = VERSION
  end
end
