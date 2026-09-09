# frozen_string_literal: true

require "yaml"

require_relative "curie"
require_relative "definitions"
require_relative "types"

module Vv
  module Linkml
    # A LinkML schema as asserted -- the YAML as written, indexed, with nothing
    # inferred. The inferred form is what Derivation produces.
    #
    # THE CONSTRUCTOR ENFORCES ONE RULE AND ONLY ONE.
    #
    # 02instances.md, on ElementName: "Names MUST NOT be shared across
    # definition types". A class named `Person` and an enum named `Person` are
    # not a namespacing question -- the instance grammar distinguishes
    # `Person(...)`, `Person[...]` and `Person&...` by punctuation alone, and a
    # name that could be two of them makes the grammar ambiguous. So this raises
    # at load rather than resolving the later definition and moving on.
    #
    # Everything else that could be checked is deferred, because a schema that
    # will not load cannot be inspected to find out why it will not load.
    class Schema
      class NameCollision < StandardError; end
      class Malformed < StandardError; end
      class UnresolvedImport < StandardError; end

      attr_reader :id, :name, :source, :imports, :prefixes, :default_prefix,
                  :classes, :slots, :enums, :types, :subsets, :settings, :raw

      # Loads from a YAML file path.
      def self.load_file(path, **kwargs)
        raw = YAML.safe_load_file(path.to_s, aliases: true, permitted_classes: [Date, Time])
        raise Malformed, "#{path}: expected a YAML mapping, got #{raw.class}" unless raw.is_a?(Hash)

        new(raw, source: path.to_s, **kwargs)
      end

      # Loads from a YAML string.
      def self.load(yaml, source: "(string)", **kwargs)
        raw = YAML.safe_load(yaml, aliases: true, permitted_classes: [Date, Time])
        raise Malformed, "#{source}: expected a YAML mapping, got #{raw.class}" unless raw.is_a?(Hash)

        new(raw, source: source, **kwargs)
      end

      def initialize(raw, source: nil)
        @raw = raw.to_h { |k, v| [k.to_s, v] }.freeze
        @source = source
        @id = @raw["id"]
        @name = @raw["name"]
        @imports = Array(@raw["imports"]).map(&:to_s).freeze
        @default_prefix = @raw["default_prefix"]
        @prefixes = Curie::Prefixes.new(parse_prefixes(@raw["prefixes"]))
        @settings = (@raw["settings"] || {}).to_h { |k, v| [k.to_s, v] }.freeze

        @classes = build(@raw["classes"], ClassDefinition)
        # The metaslot is `slot_definitions`; the YAML key is `slots`. meta.yaml
        # says so: "the formal name of this element is slot_definitions, but it
        # has alias slots, which is the canonical form used in yaml/json
        # serializes of schemas."
        @slots = build(@raw["slots"] || @raw["slot_definitions"], SlotDefinition)
        @enums = build(@raw["enums"], EnumDefinition)
        @types = build(@raw["types"], TypeDefinition)
        @subsets = build(@raw["subsets"], SubsetDefinition)

        detect_collisions!

        # Computed before the freeze rather than memoized after it: the schema is
        # immutable by design, and a lazily-populated ivar would be the one thing
        # that could not be.
        @elements = [@classes, @slots, @enums, @types, @subsets]
                    .reduce({}) { |acc, h| acc.merge(h) }.freeze
        @all_slot_definitions =
          (@slots.values +
           @classes.values.flat_map { |c| c.attributes.values + c.slot_usage.values }).freeze

        freeze
      end

      # 04derived-schemas.md, "Rule: Populate Schema Metadata": "if
      # m'.default_range is not set, set it to `string`."
      #
      # Note the rule is applied per schema in the import closure, not once to
      # the top-level schema -- an imported schema keeps its own default_range.
      DEFAULT_RANGE_FALLBACK = "string"

      def default_range = @raw["default_range"] || DEFAULT_RANGE_FALLBACK

      # True when default_range was written rather than supplied by the rule
      # above. The distinction matters: it is the difference between a schema
      # that chose strings and one that never thought about ranges.
      def default_range_asserted? = !@raw["default_range"].nil?

      # Every element, by name. The uniqueness rule means this loses nothing.
      attr_reader :elements

      def element(name) = elements[name.to_s]

      def class_def(name) = @classes[name.to_s]
      def slot(name) = @slots[name.to_s]
      def enum(name) = @enums[name.to_s]
      def type(name) = @types[name.to_s]

      # A type by name, falling back to the LinkML built-ins. Returns nil for an
      # unresolvable name rather than guessing -- see Types.miscased for why
      # `Boolean` is the interesting failure.
      def resolve_type(name)
        return nil if name.nil?

        @types[name.to_s] || builtin_type(name)
      end

      # What kind of element a range names: :class, :enum, :type, :builtin_type,
      # or nil when it resolves to nothing.
      def range_metatype(name)
        return nil if name.nil?

        n = name.to_s
        return :class if @classes.key?(n)
        return :enum if @enums.key?(n)
        return :type if @types.key?(n)
        return :builtin_type if Types.builtin?(n)

        nil
      end

      # Ranges that name nothing. LinkML does not raise on these -- the range
      # simply fails to resolve -- so they are worth asking for by name.
      def unresolvable_ranges
        all_slot_definitions.filter_map do |slot|
          r = slot.range
          next if r.nil?
          next if range_metatype(r)

          [slot.name, r, Types.miscased(r)]
        end
      end

      # Every SlotDefinition in the schema: top-level slots, plus every class's
      # attributes and slot_usage entries.
      attr_reader :all_slot_definitions

      # Imports as written. Resolving them needs a resolver; see
      # Derivation.import_closure. A schema is not complete without them, and
      # this gem will not pretend a schema with unresolved imports is whole.
      def imports? = !@imports.empty?

      # The class marked `tree_root: true`, if any. 06mapping.md's JSON parsing
      # takes a target ElementName; tree_root is how a schema names its default.
      def tree_root = @classes.values.find(&:tree_root?)

      # The prefix map plus the ':' entry the CURIE grammar allows -- an empty
      # prefix resolves against default_prefix.
      def expanded_prefixes
        base = @prefixes.map.dup
        base[""] = @prefixes[@default_prefix] if @default_prefix && @prefixes.key?(@default_prefix)
        Curie::Prefixes.new(base)
      end

      # The URI that ModelURI() prefixes onto element names, or nil when
      # default_prefix names no entry in the prefix map.
      #
      # nil is a real answer, not a failure to try. 04derived-schemas.md derives
      # every unset class_uri and slot_uri as `<default_prefix>:<name>`; with no
      # expansion for default_prefix, that CURIE has no URI, and emitting one
      # anyway is how a schema ends up full of IRIs that parse and do not
      # resolve.
      def default_namespace
        return nil if @default_prefix.nil?

        @prefixes[@default_prefix] || (@prefixes.uri?(@default_prefix) ? @default_prefix : nil)
      end

      def to_s = "#<Vv::Linkml::Schema #{(@name || @id).inspect}>"
      alias inspect to_s

      private

      def builtin_type(name)
        bt = Types[name]
        return nil unless bt

        TypeDefinition.new(bt.name, "type_uri" => bt.curie, "base" => bt.base,
                                    "repr" => bt.repr, "description" => bt.description)
      end

      def parse_prefixes(raw)
        return {} if raw.nil?

        raw.to_h do |k, v|
          # The Prefix metaclass has prefix_prefix/prefix_reference; the YAML
          # shorthand is a plain string value. Both appear in the wild.
          ref = v.is_a?(Hash) ? (v["prefix_reference"] || v[:prefix_reference]) : v
          [k.to_s, ref.to_s]
        end
      end

      def build(raw, klass)
        return {}.freeze if raw.nil?

        entries =
          case raw
          when Hash then raw.map { |k, v| [k.to_s, v || {}] }
          when Array
            # The list form: each entry is a mapping with a `name` (or `text`)
            # key. Rarer than the dict form but valid.
            raw.map do |e|
              raise Malformed, "expected a mapping in a #{klass} list, got #{e.class}" unless e.is_a?(Hash)

              n = e["name"] || e[:name] || e["text"] || e[:text]
              raise Malformed, "a #{klass} in list form must have a name" if n.nil?

              [n.to_s, e]
            end
          else
            raise Malformed, "expected a mapping or list for #{klass}, got #{raw.class}"
          end

        entries.to_h { |n, body| [n, klass.new(n, body)] }.freeze
      end

      # 02instances.md: "Names MUST NOT be shared across definition types".
      def detect_collisions!
        seen = {}
        [[@classes, "class"], [@slots, "slot"], [@enums, "enum"],
         [@types, "type"], [@subsets, "subset"]].each do |table, kind|
          table.each_key do |n|
            if seen.key?(n)
              raise NameCollision,
                    "#{n.inspect} is defined both as a #{seen[n]} and as a #{kind} " \
                    "in #{@name || @id || @source}. 02instances.md requires element " \
                    "names to be unique across definition types: the instance " \
                    "grammar tells #{n}(...), #{n}[...] and #{n}&... apart by " \
                    "punctuation, so a shared name makes an instance ambiguous."
            end
            seen[n] = kind
          end
        end
      end
    end
  end
end
