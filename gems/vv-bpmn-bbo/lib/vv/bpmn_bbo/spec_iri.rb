# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

require "active_support/concern"

module Vv
  module BpmnBbo
    # Derived, never a column. Grain is (definition_key, version, element_id).
    module SpecIri
      extend ActiveSupport::Concern

      def spec_iri
        ver = respond_to?(:definition_version) ? definition_version : process&.definition_version
        return nil if ver.nil? || !respond_to?(:element_id)

        key = ver.package.definition_key
        "urn:mm:bpmn:#{key}:#{ver.version}:#{element_id}"
      end
    end
  end
end
