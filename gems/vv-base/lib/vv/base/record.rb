# frozen_string_literal: true

require "active_record"

module Vv
  module Base
    # The gem's own abstract AR base. A gem must not define the host's
    # ApplicationRecord.
    class Record < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
