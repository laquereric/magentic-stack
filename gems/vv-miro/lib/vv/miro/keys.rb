# frozen_string_literal: true

module Vv
  module Miro
    # Snake_case at the Ruby boundary, camelCase on the Miro REST wire
    # for item bodies. Query params stay snake_case (`team_id`, `cursor`).
    #
    # Nested hashes under `data` still camelize (`fill_color` → `fillColor`)
    # because that is Miro's item style object, not a caller schema.
    module Keys
      module_function

      def camel_key(key)
        s = key.to_s
        return s if s.empty? || s == s.upcase
        return s unless s.include?("_")

        head, *rest = s.split("_")
        head + rest.map { |p| p.capitalize }.join
      end

      # Query strings stay snake_case (`team_id`, `cursor`). Item bodies
      # camelize (`fill_color` → `fillColor`, `board_id` → `boardId`).
      def to_wire(value, query: false)
        case value
        when Array
          value.map { |v| to_wire(v, query: query) }
        when Hash
          value.each_with_object({}) do |(k, v), out|
            key = query ? k.to_s : camel_key(k)
            out[key] = to_wire(v, query: false)
          end
        else
          value
        end
      end

      def compact(hash)
        return {} if hash.nil?

        hash.each_with_object({}) do |(k, v), out|
          next if v.nil?

          out[k] = v
        end
      end
    end
  end
end
