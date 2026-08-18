# frozen_string_literal: true
module RailsThreedotBack
  class ApplicationRecord < ::ActiveRecord::Base
    self.abstract_class = true
  end
end
