# frozen_string_literal: true

module Vv
  module CalCom
    # Snake_case at the Ruby boundary, camelCase on the Cal.com REST wire.
    #
    # Query params camelize the same way (`event_type_id` → `eventTypeId`,
    # `time_zone` → `timeZone`). Nested hashes under metadata / booking
    # field responses keep the caller's keys — those are the booker's
    # schema, not Cal.com's.
    module Keys
      PASSTHROUGH_CHILDREN = %w[
        metadata
        booking_fields_responses
        bookingFieldsResponses
        responses
        custom_inputs
        customInputs
        user_fields_responses
        userFieldsResponses
      ].freeze

      module_function

      def camel_key(key)
        s = key.to_s
        return s if s.empty? || s == s.upcase
        return s unless s.include?("_")

        head, *rest = s.split("_")
        head + rest.map { |p| p.capitalize }.join
      end

      def to_wire(value, passthrough: false)
        case value
        when Array
          value.map { |v| to_wire(v, passthrough: passthrough) }
        when Hash
          value.each_with_object({}) do |(k, v), out|
            key = passthrough ? k.to_s : camel_key(k)
            nested = passthrough || passthrough_children?(k)
            out[key] = to_wire(v, passthrough: nested)
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

      def passthrough_children?(key)
        PASSTHROUGH_CHILDREN.include?(key.to_s)
      end
    end
  end
end
