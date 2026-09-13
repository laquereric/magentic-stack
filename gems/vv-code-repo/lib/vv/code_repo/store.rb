# frozen_string_literal: true

require "thread"

module Vv
  module CodeRepo
    # In-process catalog. BACK AR is the destination store; this is the
    # seam CPCP can call before migrations exist.
    module Store
      module_function

      def mutex
        @mutex ||= Mutex.new
      end

      def by_digest
        @by_digest ||= {}
      end

      def by_slug
        @by_slug ||= {}
      end

      def bindings
        @bindings ||= Hash.new { |h, k| h[k] = [] }
      end

      def reset!
        mutex.synchronize do
          @by_digest = {}
          @by_slug = {}
          @bindings = Hash.new { |h, k| h[k] = [] }
        end
      end

      def write(rev)
        mutex.synchronize do
          by_digest[rev[:digest]] = rev
          by_slug[rev[:slug]] = rev unless rev[:slug].to_s.empty?
        end
        rev
      end

      def fetch(digest: nil, slug: nil)
        mutex.synchronize do
          if digest.to_s != ""
            by_digest[digest.to_s]
          elsif slug.to_s != ""
            by_slug[slug.to_s]
          end
        end
      end

      def list
        mutex.synchronize { by_slug.values }
      end

      def bind(digest, binding)
        mutex.synchronize { bindings[digest] << binding }
        binding
      end

      def bindings_for(digest)
        mutex.synchronize { bindings[digest].dup }
      end
    end
  end
end
