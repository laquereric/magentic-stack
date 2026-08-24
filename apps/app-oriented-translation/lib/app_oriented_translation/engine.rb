# frozen_string_literal: true
require "rails/engine"

module AppOrientedTranslation
  # Additive Rails engine. It exists so the page shell is ONE file --
  # app/views/layouts/app_oriented_translation/application.html.erb -- shared by
  # every surface that renders a Profile 9 ACIA document, instead of a heredoc
  # duplicated per build script.
  class Engine < ::Rails::Engine
    isolate_namespace AppOrientedTranslation
  end
end
