# frozen_string_literal: true

require "rake"
require_relative "../dependency_orch"

module Vv
  module DependencyOrch
    # The POC entry point.
    #
    # EVERY TASK IS THE SAME THREE LINES: read arguments, call one library
    # function, print the rendered envelope. No task branches on a domain fact,
    # and that is a gate rather than a style note -- if a task held logic, the
    # CLI that comes later could not be a second presentation of the same model,
    # and the two surfaces would begin to answer differently.
    #
    # The one place that looks like an exception is `inventory_for`, which is
    # shared setup rather than per-task logic: it builds the graph the same way
    # for every task, so there is one answer to "what was looked at".
    #
    # Rails is never loaded here, and running these tasks with the app's
    # dependencies absent is the check that it stays that way.
    module Tasks
      # Rake's `namespace` and `task` are DSL methods mixed into main, not
      # methods on a module. `install` calls them from inside this module, so
      # without this the whole entry point raises NoMethodError on `namespace`
      # before a single task is defined -- the specs do not catch it because
      # they exercise the library, and `install` is the one line only the
      # Rakefile runs.
      extend ::Rake::DSL

      module_function

      # Roots to read declarations from. Configured, not discovered: a search
      # for likely sibling checkouts would eventually find the wrong one, and a
      # graph built against another tree's pins is worse than no graph.
      def roots
        configured = ENV["ORCH_ROOTS"].to_s.split(":").reject(&:empty?)
        return configured unless configured.empty?

        [git_toplevel || Dir.pwd]
      end

      def git_toplevel
        status, out, = Adapters::Base.run(%w[git rev-parse --show-toplevel], timeout: 5)
        status == :ok && !out.strip.empty? ? out.strip : nil
      end

      def format = (ENV["FORMAT"] || "text").to_sym

      def local? = ENV["ORCH_LOCAL"] != "0"

      def emit(view, envelope)
        puts Render.call(view, envelope, format: format)
        # A refusal is not a crash, and rake should not print a backtrace for
        # one -- but it must not exit 0 either, or a CI job treats "we could not
        # look" as "we looked and it was fine".
        exit(1) unless envelope[:ok]
      end

      def inventory_for
        result = DependencyOrch.inventory(roots: roots, local: local?)
        [result[:graph], result[:notes]]
      end

      def install
        namespace :orch do
          desc "Which adapters can answer, and which cannot"
          task :doctor do
            Tasks.emit(:doctor, DependencyOrch.doctor(roots: Tasks.roots))
          end

          desc "Every resource, every placement [kind: repo|local|remote]"
          task :resources, [:kind] do |_t, args|
            graph, notes = Tasks.inventory_for
            Tasks.emit(:resources, DependencyOrch.resource_list(graph, kind: args[:kind], notes: notes))
          end

          desc "Identity, placements and both edge sets for one resource"
          task :show, [:reference] do |_t, args|
            graph, = Tasks.inventory_for
            Tasks.emit(:show, DependencyOrch.show(graph, args[:reference]))
          end

          desc "Forward: what this depends on, transitively"
          task :deps, %i[reference depth] do |_t, args|
            graph, = Tasks.inventory_for
            Tasks.emit(:deps, DependencyOrch.deps(graph, args[:reference], depth: (args[:depth] || 3).to_i))
          end

          namespace :deps do
            desc "Reverse: if this moves, which lines declare it and which reference it"
            task :reverse, [:reference] do |_t, args|
              graph, = Tasks.inventory_for
              Tasks.emit(:reverse, DependencyOrch.blast_radius(graph, args[:reference]))
            end
          end

          desc "Declared vs placed, everywhere we could reach"
          task :drift do
            graph, notes = Tasks.inventory_for
            Tasks.emit(:drift, DependencyOrch.drift(graph, notes: notes))
          end

          desc "Export the graph as JSON"
          task :graph do
            graph, notes = Tasks.inventory_for
            Tasks.emit(:graph, Export.call(graph, format: :json, notes: notes))
          end

          namespace :graph do
            desc "Export the graph as mermaid"
            task :mermaid do
              graph, notes = Tasks.inventory_for
              Tasks.emit(:graph, Export.call(graph, format: :mermaid, notes: notes))
            end
          end
        end
      end
    end
  end
end
