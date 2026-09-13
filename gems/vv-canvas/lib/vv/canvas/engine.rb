# frozen_string_literal: true

module Vv
  module Canvas
    class Engine < ::Rails::Railtie
      initializer "vv_canvas.cpcp" do
        config.after_initialize { Cpcp.register! }
      end
    end
  end
end
