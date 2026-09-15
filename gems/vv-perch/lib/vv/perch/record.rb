# frozen_string_literal: true

require "active_record"

module Vv
  module Perch
    # The gem's own abstract AR base. A gem must not define the host's
    # ApplicationRecord.
    class Record < ActiveRecord::Base
      self.abstract_class = true
      self.table_name_prefix = "perch_"
    end
  end
end
