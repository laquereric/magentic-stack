# frozen_string_literal: true
module Vv
  module Slo
    # Google SRE Workbook burn-rate tiers.
    #
    # Each tier names its OWN pair of windows. A tier fires only when BOTH of
    # its windows exceed the factor -- that pairing is what filters false
    # alarms, and it is why a single long/short number cannot classify all
    # three tiers.
    module BurnRate
      TIERS = [
        { name: :page,   factor: 14.4, long: "1h", short: "5m",  action: "wake a human" },
        { name: :page,   factor: 6.0,  long: "6h", short: "30m", action: "wake a human" },
        { name: :ticket, factor: 1.0,  long: "3d", short: "6h",  action: "a ticket is enough" }
      ].freeze

      module_function

      # burn = observed error rate / allowed error rate
      def burn(observed_error_rate:, error_budget:)
        return nil if error_budget.nil? || error_budget.zero?
        (observed_error_rate / error_budget.to_f).round(3)
      end

      # burns: a hash of window => burn rate, e.g.
      #   { "5m" => 20.0, "1h" => 18.2, "30m" => 9.0, "6h" => 4.0, "3d" => 1.1 }
      # A window absent from the hash cannot satisfy its tier.
      def classify(burns)
        b = (burns || {}).transform_keys(&:to_s)
        TIERS.each do |t|
          l = b[t[:long]]
          s = b[t[:short]]
          next if l.nil? || s.nil?
          return t.merge(fired: true, longBurn: l, shortBurn: s) if l >= t[:factor] && s >= t[:factor]
        end
        { name: :none, fired: false, action: "no alert" }
      end
    end
  end
end
