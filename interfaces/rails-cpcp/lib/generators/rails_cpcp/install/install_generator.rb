# frozen_string_literal: true
require "rails/generators/base"
module RailsCpcp
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Install rails-cpcp: an initializer + a Kamal two-pod (BACK+FRONT) deploy template."

      def create_initializer
        copy_file "rails_cpcp.rb", "config/initializers/rails_cpcp.rb"
      end

      def create_deploy_template
        copy_file "deploy.cpcp.yml", "config/deploy.cpcp.yml"
      end

      def show_next_steps
        say "\nrails-cpcp installed. Next:", :green
        say '  1) Mount the engine in config/routes.rb:   mount RailsCpcp::Engine => "/_cpcp"'
        say "  2) Declare projections in config/initializers/rails_cpcp.rb"
        say "  3) Two-pod deploy: build front/ image, then kamal deploy -c config/deploy.cpcp.yml"
      end
    end
  end
end
