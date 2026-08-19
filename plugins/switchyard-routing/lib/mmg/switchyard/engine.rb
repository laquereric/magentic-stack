# frozen_string_literal: true
require "rails/engine"
module Mmg
  module Switchyard
    class Engine < ::Rails::Engine
      isolate_namespace Mmg::Switchyard
    end
  end
end
