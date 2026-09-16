# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1
module Mmg
  module Medallion
    # SEMANTIC MODEL — a Gold-tier governed product's meaning: an IRI-identified, versioned model with an
    # owner and a definition (DataLayer.md fold-in). Immutable value object; never-raise construction.
    SemanticModel = Struct.new(:iri, :version, :status, :owner, :definition, keyword_init: true) do
      def governed? = status.to_s == "governed"
    end
  end
end
