# frozen_string_literal: true
module Vv
  module Slo
    # An SLO the pipeline can QUERY, not a number on a dashboard.
    #
    #   SLI = the raw measurement
    #   SLO = the internal target for it
    #   SLA = the contractual promise with penalties
    #
    # error budget = 1 - target. At 99.9% over 30d that is ~43 minutes.
    class Objective
      WINDOWS = %w[1h 6h 3d 7d 30d].freeze

      attr_reader :service, :target, :time_window, :good_query, :total_query

      def initialize(service:, target:, time_window: "30d", good_query: nil, total_query: nil)
        @service = service.to_s
        @target = target
        @time_window = time_window.to_s
        @good_query = good_query
        @total_query = total_query
      end

      # Never-raise: { ok: true, ... } | { ok: false, reason:, because: }
      def validate
        return fail_r(:service_required, "service must be a non-empty string") if service.empty?
        unless target.is_a?(Numeric) && target > 0 && target < 1
          return fail_r(:target_invalid, "target must be a ratio strictly between 0 and 1, got #{target.inspect}")
        end
        unless WINDOWS.include?(time_window)
          return fail_r(:window_invalid, "timeWindow must be one of #{WINDOWS.join(', ')}, got #{time_window.inspect}")
        end
        if good_query.to_s.empty? || total_query.to_s.empty?
          return fail_r(:unqueryable, "an SLO without good/total queries cannot be evaluated by a pipeline")
        end
        { ok: true, service: service, target: target, timeWindow: time_window,
          errorBudget: error_budget, budgetMinutes: budget_minutes }
      end

      def error_budget = 1.0 - target

      # Minutes of unreliability the window permits.
      def budget_minutes
        mins = { "1h" => 60, "6h" => 360, "3d" => 4320, "7d" => 10_080, "30d" => 43_200 }[time_window]
        return nil unless mins
        (mins * error_budget).round(2)
      end

      def to_openslo
        { "kind" => "SLO",
          "spec" => { "service" => service,
                      "objectives" => [{ "ratioMetric" => { "good" => { "query" => good_query },
                                                            "total" => { "query" => total_query } },
                                         "target" => target,
                                         "timeWindow" => time_window }] } }
      end

      private

      def fail_r(reason, because) = { ok: false, reason: reason, because: because }
    end
  end
end
