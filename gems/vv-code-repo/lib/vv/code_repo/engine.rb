# frozen_string_literal: true

module Vv
  module CodeRepo
    class Engine < ::Rails::Railtie
      initializer "vv_code_repo.cpcp" do
        config.after_initialize { Cpcp.register! }
      end
    end
  end
end
