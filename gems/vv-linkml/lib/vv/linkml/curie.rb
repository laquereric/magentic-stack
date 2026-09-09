# frozen_string_literal: true

module Vv
  module Linkml
    # The URI and CURIE functions of 04derived-schemas.md, plus the three
    # name-mangling functions that section uses and never defines.
    #
    # `URI(s, v)` and `CURIE(s, v)` are specified: expand a CURIE through the
    # schema's prefix map, contract a URI by the longest matching prefix
    # ("The one with the shortest reference is chosen as the canonical").
    #
    # `Safe`, `SafeCamel` and `SafeSnake` are not. They appear once each, in the
    # Element URI table:
    #
    #     | ClassDefinition  | e.class_uri | <m.default_prefix>:<SafeCamel(e.name)> |
    #     | SlotDefinition   | e.slot_uri  | <m.default_prefix>:<SafeSnake(e.name)> |
    #     | PermissibleValue | e.meaning   | ModelURI(Enum) + "." + Safe(e.text)    |
    #
    # and nowhere else in the specification. They decide every derived class_uri
    # and slot_uri in every LinkML schema. What follows is an *interpretation*,
    # matched to what the reference implementation emits, and every URI this gem
    # derives carries `derived: true` so a caller can tell a computed IRI from a
    # declared one.
    module Curie
      # W3C CURIE Syntax 1.0, as 04derived-schemas.md cites it:
      #   curie := [ [ prefix ] ':' ] reference
      #   prefix := NCName
      NCNAME = /\A[A-Za-z_][A-Za-z0-9_.\-]*\z/

      class UnknownPrefix < StandardError; end

      # A prefix map: prefix_prefix => prefix_reference, per the Prefix
      # metaclass.
      class Prefixes
        attr_reader :map

        def initialize(map = {})
          @map = map.transform_keys(&:to_s).transform_values(&:to_s).freeze
        end

        def [](prefix) = @map[prefix.to_s]
        def key?(prefix) = @map.key?(prefix.to_s)
        def empty? = @map.empty?
        def names = @map.keys
        def merge(other) = Prefixes.new(@map.merge(other.respond_to?(:map) ? other.map : other))

        # URI(s, v). Returns nil when the CURIE's prefix is not in the map --
        # deliberately, rather than concatenating something plausible. A prefix
        # that is not declared has no expansion, and inventing one mints an IRI
        # that parses and does not resolve.
        def expand(value)
          return nil if value.nil?

          v = value.to_s
          return v if uri?(v)

          prefix, reference = Curie.split(v)
          return nil if prefix.nil?

          base = @map[prefix]
          return nil if base.nil?

          "#{base}#{reference}"
        end

        def expand!(value)
          expand(value) or
            raise UnknownPrefix,
                  "cannot expand #{value.inspect}: prefix " \
                  "#{Curie.split(value.to_s).first.inspect} is not in the schema's " \
                  "prefix map (#{names.empty? ? 'which is empty' : names.join(', ')}). " \
                  "04derived-schemas.md expands a CURIE by concatenating " \
                  "m.prefixes[prefix].prefix_reference with the reference; with no " \
                  "entry there is nothing to concatenate."
        end

        # CURIE(s, v). Contracts by the longest matching prefix_reference, which
        # is what "the one with the shortest reference is chosen as the
        # canonical" amounts to. Returns nil when no prefix matches.
        def contract(uri)
          return nil if uri.nil?

          u = uri.to_s
          best = @map.select { |_, ref| u.start_with?(ref) && u != ref }
                     .max_by { |_, ref| ref.length }
          return nil unless best

          "#{best[0]}:#{u.delete_prefix(best[1])}"
        end

        # True for a string that is an absolute URI rather than a CURIE.
        #
        # The two grammars genuinely overlap: `http:foo` parses as a CURIE with
        # prefix `http`, and the specification gives no disambiguation rule. The
        # rule applied here is the one that matches practice -- a `://`
        # authority, or the `urn:` scheme -- and a declared prefix always wins,
        # so a schema that maps a prefix named `http` gets its own map honoured.
        def uri?(value)
          v = value.to_s
          prefix, = Curie.split(v)
          return false if prefix && @map.key?(prefix)

          v.include?("://") || v.start_with?("urn:")
        end
      end

      # Decomposes a CURIE into [prefix, reference]. A value with no colon has
      # no prefix; a value beginning with ':' has the empty prefix, which the
      # CURIE grammar allows and which LinkML resolves against default_prefix.
      def self.split(value)
        v = value.to_s
        idx = v.index(":")
        return [nil, v] if idx.nil?

        [v[0...idx], v[(idx + 1)..]]
      end

      class << self
        # SafeCamel(name). INTERPRETATION -- the specification does not define
        # this function.
        #
        # Splits on the separators that appear in LinkML element names
        # (underscore, hyphen, space), uppercases the first letter of each part,
        # and joins. A name that is already CamelCase survives unchanged, because
        # only the first letter of each part is touched: "NamedThing" stays
        # "NamedThing" rather than becoming "Namedthing".
        def safe_camel(name)
          parts = name.to_s.split(/[\s_\-]+/).reject(&:empty?)
          return safe(name.to_s) if parts.empty?

          safe(parts.map { |p| p.sub(/\A[a-z]/, &:upcase) }.join)
        end

        # SafeSnake(name). INTERPRETATION -- likewise undefined.
        #
        # Lowercases, and turns runs of separator characters into a single
        # underscore. A CamelCase name has its word boundaries broken:
        # "vitalStatus" becomes "vital_status".
        def safe_snake(name)
          s = name.to_s
                  .gsub(/([a-z0-9])([A-Z])/, '\1_\2')
                  .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                  .gsub(/[\s\-]+/, "_")
                  .downcase
          safe(s.gsub(/_+/, "_").gsub(/\A_|_\z/, ""))
        end

        # Safe(text). INTERPRETATION -- undefined; used only for permissible
        # value meanings.
        #
        # Percent-encodes anything outside the unreserved set of RFC 3986, so
        # that the result can sit in the reference part of a CURIE without
        # changing its parse. A permissible value like "Forklift Driver" becomes
        # "Forklift%20Driver".
        def safe(text)
          text.to_s.gsub(/[^A-Za-z0-9._~\-]/) do |ch|
            ch.bytes.map { |b| format("%%%02X", b) }.join
          end
        end

        def ncname?(value) = value.to_s.match?(NCNAME)
      end
    end
  end
end
