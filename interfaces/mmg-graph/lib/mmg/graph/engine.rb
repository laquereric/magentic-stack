# frozen_string_literal: true
module Mmg
  module Graph
    class Engine < ::Rails::Engine
      isolate_namespace Mmg::Graph
    end
  end
end
