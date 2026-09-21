# frozen_string_literal: true

module Vv
  module CpcpHarness
    # A reader for the conservative slice of SHACL the generator can turn
    # into a local input schema (design §6.3).
    #
    # The local schema is a courtesy: it gives the model fast, legible
    # feedback for obvious mistakes. The seam's own SHACL check is the one
    # that counts, and anything outside this slice is left permissive on
    # purpose rather than guessed at.
    module Shacl
      DATATYPES = {
        "xsd:string" => :string,
        "xsd:integer" => :integer,
        "xsd:int" => :integer,
        "xsd:long" => :integer,
        "xsd:decimal" => :number,
        "xsd:double" => :number,
        "xsd:float" => :number,
        "xsd:boolean" => :boolean,
        "xsd:dateTime" => :string,
        "xsd:date" => :string,
        "xsd:anyURI" => :string
      }.freeze

      SUPPORTED = %w[
        sh:path sh:datatype sh:minCount sh:maxCount sh:in sh:pattern
        sh:minLength sh:maxLength sh:name sh:description sh:nodeKind
      ].freeze

      Property = Struct.new(:name, :path, :type, :required, :array, :enum, :pattern,
                            :min_length, :max_length, :permissive, :description,
                            keyword_init: true)

      Shape = Struct.new(:name, :target_class, :closed, :properties, :warnings, keyword_init: true) do
        def closed? = closed == true

        def property(name)
          properties.find { |p| p.name == name.to_s }
        end
      end

      module_function

      # Parse every `sh:NodeShape` in a Turtle document. Returns an array
      # of Shape; a document this reader cannot make sense of yields an
      # empty array, and the caller falls back to the informal params.
      def parse(ttl)
        text, strings = mask_strings(ttl.to_s)
        text.split(/\.\s*(?:\n|\z)/).filter_map do |statement|
          next nil unless statement.match?(/\ba\s+sh:NodeShape\b/)

          parse_shape(statement, strings)
        end
      end

      def parse_shape(statement, strings)
        name = statement[/\A\s*([^\s]+)\s+a\s+sh:NodeShape/, 1]
        target = statement[/sh:targetClass\s+([^\s;\]]+)/, 1]
        closed = statement.match?(/sh:closed\s+true/)
        warnings = []

        properties = statement.scan(/sh:property\s*\[(.*?)\]/m).map do |(block)|
          parse_property(block, strings, warnings)
        end.compact

        Shape.new(name: name, target_class: target, closed: closed,
                  properties: properties, warnings: warnings)
      end

      def parse_property(block, strings, warnings)
        path = block[/sh:path\s+([^\s;\]]+)/, 1]
        return nil if path.nil?

        name = local_name(path)
        unsupported = block.scan(/\bsh:[A-Za-z]+/).uniq - SUPPORTED
        unless unsupported.empty?
          warnings << "#{name}: #{unsupported.join(", ")} is outside the supported subset; " \
                      "the field is left permissive and the seam decides"
        end

        datatype = block[/sh:datatype\s+([^\s;\]]+)/, 1]
        min_count = block[/sh:minCount\s+(\d+)/, 1]&.to_i
        max_count = block[/sh:maxCount\s+(\d+)/, 1]&.to_i
        enum = parse_in(block, strings)
        pattern = unmask(block[/sh:pattern\s+("__cpcp_str_\d+__")/, 1], strings)
        pattern = pattern&.delete_prefix('"')&.delete_suffix('"')

        Property.new(
          name: name,
          path: path,
          type: DATATYPES[datatype] || :any,
          required: min_count.to_i.positive?,
          # `sh:maxCount 1` is a scalar; anything else may repeat.
          array: max_count != 1,
          enum: enum,
          pattern: pattern,
          min_length: block[/sh:minLength\s+(\d+)/, 1]&.to_i,
          max_length: block[/sh:maxLength\s+(\d+)/, 1]&.to_i,
          permissive: !unsupported.empty?,
          description: unmask(block[/sh:description\s+("__cpcp_str_\d+__")/, 1], strings)
                         &.delete_prefix('"')&.delete_suffix('"')
        )
      end

      # `sh:in ( "draft" "published" )`
      def parse_in(block, strings)
        raw = block[/sh:in\s*\((.*?)\)/m, 1]
        return nil if raw.nil?

        values = raw.scan(/"__cpcp_str_\d+__"|[^\s()]+/).map do |token|
          value = unmask(token, strings)
          value.start_with?('"') ? value.delete_prefix('"').delete_suffix('"') : value
        end
        values.empty? ? nil : values
      end

      def local_name(iri)
        iri.to_s.sub(/\A</, "").sub(/>\z/, "").split(/[#:\/]/).last.to_s
      end

      # Quoted literals are masked before the document is split on `.`,
      # so a period inside a `sh:pattern` cannot end a statement.
      def mask_strings(text)
        strings = []
        masked = text.gsub(/"(?:[^"\\]|\\.)*"/) do |match|
          strings << match
          "\"__cpcp_str_#{strings.length - 1}__\""
        end
        [masked, strings]
      end

      def unmask(token, strings)
        return nil if token.nil?

        token.gsub(/"__cpcp_str_(\d+)__"/) { strings[Regexp.last_match(1).to_i] }
      end
    end
  end
end
