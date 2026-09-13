# frozen_string_literal: true

require "thread"

module Vv
  module SelfLearn
    module Store
      module_function

      def mutex
        @mutex ||= Mutex.new
      end

      def bronze
        @bronze ||= []
      end

      def last_eval
        @last_eval
      end

      def reset!
        mutex.synchronize do
          @bronze = []
          @last_eval = nil
        end
      end

      def collect(row)
        mutex.synchronize { bronze << row }
        row
      end

      def save_eval(row)
        mutex.synchronize { @last_eval = row }
        row
      end
    end
  end
end
