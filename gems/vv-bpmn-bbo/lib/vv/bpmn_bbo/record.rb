# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

require "active_record"

module Vv
  module BpmnBbo
    # The gem's own abstract AR base. A gem must not define the host's
    # ApplicationRecord.
    class Record < ActiveRecord::Base
      self.abstract_class = true
      self.table_name_prefix = "bpmn_bbo_"
    end
  end
end
