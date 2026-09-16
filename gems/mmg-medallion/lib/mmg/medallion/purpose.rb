# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1
module Mmg
  module Medallion
    # PURPOSE — the data-layering intent a tier serves (DataLayer.md fold-in). BUILD is the default
    # (back-compat with existing medallion semantics); CONSUME = projection/read-model plane; OPERATE =
    # governance/operations plane. Purpose is orthogonal to tier rank — a tier is actionable *for a purpose*.
    module Purpose
      BUILD   = "build"
      CONSUME = "consume"
      OPERATE = "operate"
      ALL     = [BUILD, CONSUME, OPERATE].freeze

      module_function

      def valid?(value) = ALL.include?(value.to_s.downcase)

      def normalize!(value)
        v = value.to_s.downcase
        return v if valid?(v)
        raise ArgumentError, "purpose must be build|consume|operate (got #{value.inspect})"
      end

      # Never-raise variant for the boundary: returns build|consume|operate or nil.
      def coerce(value) = valid?(value) ? value.to_s.downcase : nil
    end
  end
end
