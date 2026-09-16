# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Medallion
    # Deprecation registry: vv-medallion / Vv::Medallion → mmg-medallion.
    module Deprecation
      module_function

      ENTRIES = [
        {
          legacy: "vv-medallion",
          legacy_const: "Vv::Medallion",
          canonical: "mmg-medallion",
          canonical_const: "Mmg::Medallion",
          status: "deprecated",
          removal_policy: "retire_shim_when_registry_telemetry_shows_zero_vv_usage"
        },
        {
          legacy: "Vv::Medallion::Flow",
          canonical: "Mmg::Medallion::Flow",
          status: "deprecated"
        },
        {
          legacy: "Vv::Medallion::Conformer",
          canonical: "Mmg::Medallion::Flow#plan_projection (Conformer actuator pending P1)",
          status: "deprecated"
        },
        {
          legacy: "Vv::Medallion::Curator",
          canonical: "Mmg::Medallion Gold layer + Mmg::Curation (P3)",
          status: "deprecated"
        }
      ].freeze

      def entries = ENTRIES

      def lookup(legacy)
        ENTRIES.find { |e| e[:legacy].to_s == legacy.to_s || e[:legacy_const].to_s == legacy.to_s }
      end

      def warn_once!(legacy)
        @warned ||= {}
        return false if @warned[legacy.to_s]

        @warned[legacy.to_s] = true
        entry = lookup(legacy)
        msg = if entry
                "[mmg-medallion] #{legacy} is deprecated; use #{entry[:canonical]} instead"
              else
                "[mmg-medallion] #{legacy} is deprecated; use Mmg::Medallion"
              end
        warn(msg) if defined?(Kernel)
        true
      end

      def shim_note
        {
          ok: true,
          canonical: "Mmg::Medallion",
          deprecated: ENTRIES.map { |e| e[:legacy] },
          policy: "namespace-safe P0; shim delegates when Vv::Medallion is present"
        }
      end
    end
  end
end
