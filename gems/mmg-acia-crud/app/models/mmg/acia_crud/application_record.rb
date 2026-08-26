module Mmg
  module AciaCrud
    class ApplicationRecord < ::ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
