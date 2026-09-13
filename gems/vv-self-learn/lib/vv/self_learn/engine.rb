# frozen_string_literal: true

module Vv
  module SelfLearn
    class Engine < ::Rails::Railtie
      initializer "vv_self_learn.cpcp" do
        config.after_initialize { Cpcp.register! }
      end
    end
  end
end
