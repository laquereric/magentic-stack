# frozen_string_literal: true

module Vv
  module Figma
    # Snake_case at the Ruby boundary and on the Figma REST wire
    # (`file_key`, `node_id`, `team_id`). Unlike Miro, Figma does not
    # camelCase item bodies.
    module Keys
      module_function

      def to_wire(value, query: false)
        case value
        when Array
          value.map { |v| to_wire(v, query: query) }
        when Hash
          value.each_with_object({}) do |(k, v), out|
            out[k.to_s] = to_wire(v, query: query)
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
