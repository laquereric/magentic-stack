# frozen_string_literal: true

module Vv
  module CpcpHarness
    # The local input schema for one tool: built from a CID's SHACL where
    # the shapes allow it, and from the operation's informal `params`
    # where they do not.
    #
    # It refuses what is clearly wrong before anything is sent, and lets
    # everything else through to the seam, which is the authority. A local
    # check that tried to be the authority would drift from the contract
    # and start refusing valid calls.
    class Schema
      # The bridge supplies these; a model never writes them, and a closed
      # shape must not reject them.
      EXEMPT = %w[@context operationId operation_id].freeze

      TYPE_NAMES = {
        string: "a string",
        integer: "an integer",
        number: "a number",
        boolean: "a boolean",
        any: "any value"
      }.freeze

      Field = Struct.new(:name, :type, :required, :array, :enum, :pattern,
                         :min_length, :max_length, :permissive, :description,
                         keyword_init: true)

      attr_reader :fields, :warnings

      def initialize(fields: [], closed: false, warnings: [])
        @fields = fields
        @closed = closed
        @warnings = warnings
      end

      class << self
        def from_shape(shape)
          fields = shape.properties.map do |p|
            Field.new(name: p.name, type: p.type, required: p.required, array: p.array,
                      enum: p.enum, pattern: p.pattern, min_length: p.min_length,
                      max_length: p.max_length, permissive: p.permissive,
                      description: p.description)
          end
          new(fields: fields, closed: shape.closed?, warnings: shape.warnings)
        end

        # Fallback: the CID's informal params, e.g.
        #   { "title" => "string (required)", "limit" => "integer" }
        def from_params(params)
          return permissive unless params.is_a?(Hash)

          fields = params.map do |name, spec|
            text = spec.to_s
            Field.new(
              name: name.to_s,
              type: informal_type(text),
              required: text.match?(/required/i),
              array: text.match?(/array|list/i),
              permissive: informal_type(text) == :any,
              description: text
            )
          end
          new(fields: fields, closed: false,
              warnings: params.empty? ? [] : ["input schema came from the CID's informal params, not from SHACL"])
        end

        def permissive
          new(fields: [], closed: false, warnings: [])
        end

        def informal_type(text)
          case text
          when /string|text/i then :string
          when /integer|int\b/i then :integer
          when /number|decimal|float/i then :number
          when /bool/i then :boolean
          else :any
          end
        end
      end

      def closed?
        @closed == true
      end

      def field(name)
        @fields.find { |f| f.name == name.to_s }
      end

      # A PUSH tool declares `operationId` as an *optional* string. A model
      # that knows nothing about it still gets a working call; one that
      # needs to retry the same write has a place to put the id.
      def with_operation_id
        return self if field("operationId")

        self.class.new(
          fields: @fields + [Field.new(
            name: "operationId", type: :string, required: false, array: false,
            description: "Names this write. Pass the operationId from an earlier result to retry " \
                         "that same write; omit it for a new, separate write."
          )],
          closed: @closed,
          warnings: @warnings
        )
      end

      # Returns nil when the arguments are acceptable, and a sentence
      # naming every problem when they are not.
      def validate(args)
        # `params` is always an object. A falsey non-object is not
        # silently an empty one: both layers agree on that.
        return "params must be an object, got #{args.class}" unless args.is_a?(Hash)

        given = args.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
        problems = []

        @fields.each do |f|
          unless given.key?(f.name)
            problems << "#{f.name} is required" if f.required
            next
          end

          problems.concat(check(f, given[f.name]))
        end

        if closed?
          unknown = given.keys - @fields.map(&:name) - EXEMPT
          problems << "#{unknown.join(", ")} not in the closed shape" unless unknown.empty?
        end

        problems.empty? ? nil : problems.join("; ")
      end

      # A JSON Schema for whichever agent SDK needs one.
      def json_schema
        properties = @fields.to_h do |f|
          spec = { "type" => json_type(f) }
          spec["description"] = f.description if f.description
          spec["enum"] = f.enum if f.enum
          spec["pattern"] = f.pattern if f.pattern
          spec["minLength"] = f.min_length if f.min_length
          spec["maxLength"] = f.max_length if f.max_length
          [f.name, spec]
        end

        schema = { "type" => "object", "properties" => properties }
        required = @fields.select(&:required).map(&:name)
        schema["required"] = required unless required.empty?
        schema["additionalProperties"] = false if closed?
        schema
      end

      private

      def json_type(field)
        base = case field.type
               when :string then "string"
               when :integer then "integer"
               when :number then "number"
               when :boolean then "boolean"
               else %w[string number boolean object array null]
               end
        field.array ? "array" : base
      end

      def check(field, value)
        return [] if field.permissive || field.type == :any

        values = field.array && value.is_a?(Array) ? value : [value]
        return ["#{field.name} must be a single value"] if !field.array && value.is_a?(Array)

        values.flat_map { |v| check_one(field, v) }
      end

      def check_one(field, value)
        problems = []
        problems << "#{field.name} must be #{TYPE_NAMES[field.type]}" unless typed?(field.type, value)
        return problems unless problems.empty?

        if field.enum && !field.enum.include?(value)
          problems << "#{field.name} must be one of #{field.enum.join(", ")}"
        end
        if value.is_a?(String)
          if field.pattern && !Regexp.new(field.pattern).match?(value)
            problems << "#{field.name} must match #{field.pattern}"
          end
          if field.min_length && value.length < field.min_length
            problems << "#{field.name} must be at least #{field.min_length} characters"
          end
          if field.max_length && value.length > field.max_length
            problems << "#{field.name} must be at most #{field.max_length} characters"
          end
        end
        problems
      rescue RegexpError
        problems
      end

      def typed?(type, value)
        case type
        when :string then value.is_a?(String)
        when :integer then value.is_a?(Integer)
        when :number then value.is_a?(Numeric)
        when :boolean then [true, false].include?(value)
        else true
        end
      end
    end
  end
end
