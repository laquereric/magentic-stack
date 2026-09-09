# frozen_string_literal: true

require_relative "element"
require_relative "types"

module Vv
  module Linkml
    # A ClassDefinition. 03schemas.md: instances of ClassDefinition are
    # themselves instantiable.
    class ClassDefinition < Element
      # Names listed in `slots:` -- references to top-level SlotDefinitions.
      # These are names, not definitions; the definition lives in the schema.
      def slot_names = Array(self["slots"]).map(&:to_s)

      # `attributes:` -- slots defined inline, scoped to this class. The
      # metamodel treats them as SlotDefinitions like any other, and
      # ApplicableSlots takes their union with `slots`.
      def attributes
        (self["attributes"] || {}).to_h { |k, v| [k.to_s, SlotDefinition.new(k, v || {})] }
      end

      # `slot_usage:` -- refinements of an inherited slot in this class's
      # context. A slot_usage entry is a partial SlotDefinition: it says what
      # changes, not what the slot is.
      def slot_usage
        (self["slot_usage"] || {}).to_h { |k, v| [k.to_s, SlotDefinition.new(k, v || {})] }
      end

      # DirectSlots(c) = L(c.slots) ∪ L(c.attributes)
      def direct_slot_names = (slot_names + attributes.keys).uniq

      def tree_root? = self["tree_root"] == true

      def class_uri = self["class_uri"]

      def unique_keys = self["unique_keys"] || {}

      def rules = Array(self["rules"])
    end

    # A SlotDefinition. 03schemas.md: instances of SlotDefinition are NOT
    # themselves instantiable -- a slot is how an assignment in a class instance
    # is described, not a thing with instances.
    class SlotDefinition < Element
      def range = to_name(self["range"])

      def multivalued? = self["multivalued"] == true
      def required? = self["required"] == true
      def recommended? = self["recommended"] == true
      def identifier? = self["identifier"] == true
      def key? = self["key"] == true
      def designates_type? = self["designates_type"] == true

      # meta.yaml, on both `identifier` and `key`: "An identifier slot is
      # automatically required. Identifiers cannot be optional." So the answer
      # to "must this be present" is not `required` alone.
      def effectively_required? = required? || identifier? || key?

      def inlined? = self["inlined"] == true
      def inlined_as_list? = self["inlined_as_list"] == true

      # The metamodel has `inlined`, `inlined_as_list` and
      # `inlined_as_simple_dict`. It does NOT have `inlined_as_dict`, which is
      # the metaslot 06mapping.md's collection-form procedure and
      # 04derived-schemas.md's AddMissingValues table are both written against.
      #
      # The reading applied here: "inlined as a dict" is `inlined` and not
      # `inlined_as_list`, which is how the two real metaslots partition the
      # inlined case.
      def inlined_as_dict? = inlined? && !inlined_as_list?

      def inlined_as_simple_dict? = self["inlined_as_simple_dict"] == true

      # slot_uri as written. nil means derivation supplies it -- meta.yaml gives
      # slot_uri `ifabsent: slot_curie`.
      def slot_uri = self["slot_uri"]

      # The name used for this slot inside its owning class. 03schemas.md: "the
      # name used for a slot in the context of its owning class. If present,
      # this is used instead of the actual slot name."
      def alias_name = self["alias"] || @name

      def pattern = self["pattern"]
      def minimum_value = self["minimum_value"]
      def maximum_value = self["maximum_value"]
      def minimum_cardinality = self["minimum_cardinality"]
      def maximum_cardinality = self["maximum_cardinality"]
      def ifabsent = self["ifabsent"]
      def domain = to_name(self["domain"])

      def any_of = Array(self["any_of"])
      def all_of = Array(self["all_of"])
      def none_of = Array(self["none_of"])
      def exactly_one_of = Array(self["exactly_one_of"])

      def boolean_expressions?
        !(any_of.empty? && all_of.empty? && none_of.empty? && exactly_one_of.empty?)
      end

      private

      def to_name(value)
        return nil if value.nil?

        value.to_s
      end
    end

    # A TypeDefinition. The metaslot is `type_uri`; the key written in YAML is
    # `uri`. Both reach `#uri` here.
    class TypeDefinition < Element
      def uri = self["type_uri"] || self["uri"]

      # `typeof:` names a parent type. A type with no typeof is a root type, and
      # meta.yaml comments that "every root type must have a type uri".
      def typeof = self["typeof"]&.to_s

      def root? = typeof.nil?

      # Python names carried from the metamodel. Present because they are part
      # of the type table, not because a Ruby consumer should dispatch on them.
      def base = self["base"]
      def repr = self["repr"]

      def pattern = self["pattern"]

      def builtin? = Types.builtin?(@name)
    end

    # An EnumDefinition. Instantiable: an enum's instances are its permissible
    # values.
    class EnumDefinition < Element
      def permissible_values
        raw = self["permissible_values"]
        case raw
        when nil then {}
        when Array
          # The list form. Each entry is a bare text value.
          raw.to_h { |t| [t.to_s, PermissibleValue.new(t.to_s, {})] }
        else
          raw.to_h { |k, v| [k.to_s, PermissibleValue.new(k, v || {})] }
        end
      end

      def texts = permissible_values.keys

      def enum_uri = self["enum_uri"]

      # `inherits`, `include` (spelled `include` in the metamodel), `minus`,
      # `concepts`, `reachable_from` and `matches` all widen or narrow the value
      # set beyond `permissible_values`. Derivation implements the parts that
      # need no external resource; the rest are reported, not guessed.
      def inherits = Array(self["inherits"]).map(&:to_s)
      def minus = Array(self["minus"])
      def include_exprs = Array(self["include"])
      def concepts = Array(self["concepts"]).map(&:to_s)
      def reachable_from = self["reachable_from"]
      def matches = self["matches"]

      # True when the permissible value set cannot be computed from the schema
      # alone. `reachable_from` and `matches` resolve against an external
      # ontology; 04derived-schemas.md's ResolveQuery says so explicitly.
      def dynamic? = !reachable_from.nil? || !matches.nil? || !concepts.empty?
    end

    # A PermissibleValue. Not a Definition in the metamodel -- it has no `name`,
    # it has `text` -- but it behaves as an element for our purposes.
    class PermissibleValue < Element
      alias text name

      # A CURIE or URI naming what this value means in some vocabulary. When
      # absent, part 6's RDF mapping emits the text as a literal rather than a
      # node: `<Enum>[<PV>] where PV.meaning=None` returns `Literal`, and with a
      # meaning it returns `Node(PV.meaning)`. The same enum value is a string
      # or an IRI depending on this one field.
      def meaning = self["meaning"]

      def unit = self["unit"]
    end

    # A SubsetDefinition. Subsets tag elements for a profile; the metamodel's own
    # SpecificationSubset is one.
    class SubsetDefinition < Element
    end
  end
end
