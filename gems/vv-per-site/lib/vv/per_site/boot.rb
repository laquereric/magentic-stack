# frozen_string_literal: true

require "fileutils"

module Vv
  module PerSite
    # Standalone AR boot so SIC can run the rake tasks without being a
    # Rails application. Honors DATABASE_URL; otherwise sqlite at
    # tmp/vv_per_site.sqlite3 under the current working directory.
    module Boot
      module_function

      def standalone!(database: nil)
        require "active_record"
        db = database || ENV["DATABASE_URL"] || default_sqlite
        connect!(db)
        Migrator.run!
      end

      def connect!(database)
        if sqlite_path?(database)
          begin
            require "sqlite3"
          rescue LoadError
            raise LoadError, "sqlite3 is required for standalone rake (add gem \"sqlite3\" to the Gemfile)"
          end
          path = database.sub(/\Asqlite3:/, "")
          unless path == ":memory:"
            dir = File.dirname(path)
            FileUtils.mkdir_p(dir) unless dir == "."
          end
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: path)
        else
          ActiveRecord::Base.establish_connection(database)
        end
        { ok: true, database: database }
      end

      def sqlite_path?(database)
        database.to_s.start_with?("sqlite3:") || database.to_s.end_with?(".sqlite3") || database.to_s == ":memory:"
      end

      def default_sqlite
        File.join(Dir.pwd, "tmp", "vv_per_site.sqlite3")
      end
    end
  end
end
