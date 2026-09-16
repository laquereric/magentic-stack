# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1
module Mmg
  module Medallion
    # CONTRACT — the consumer-facing agreement a Gold product publishes: which SemanticModel + SHACL shape
    # set it conforms to, and its freshness SLA (DataLayer.md fold-in). Immutable value object.
    Contract = Struct.new(:iri, :version, :semantic_model_iri, :shape_set_iri, :freshness_sla, keyword_init: true)
  end
end
