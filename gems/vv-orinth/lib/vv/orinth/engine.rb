# frozen_string_literal: true

module Vv
  module Orinth
    class Engine < ::Rails::Railtie
      initializer "vv_orinth.cpcp" do
        config.after_initialize { Cpcp.register! }
      end
    end
  end
end
