# frozen_string_literal: true

require_relative "metamodel"

module Vv
  module Linkml
    # Base for the four definition types plus PermissibleValue.
    #
    # An element holds the metaslot assignments it was written with, unchanged.
    # Nothing is defaulted at construction time -- defaults belong to derivation
    # (04derived-schemas.md), and an element that quietly carries `range:
    # "string"` because nobody wrote a range is indistinguishable from one that
    # asked for a string. `#asserted` is what the author wrote; the derived
    # values live on the objects Derivation returns.
    class Element
      # 02instances.md: ElementName is "a finite sequence of characters matching
      # the PN_LOCAL production of SPARQL and not matching any of the keyword
      # terminals of the syntax". PN_LOCAL is permissive; what matters in
      # practice is that names are non-empty and unique across ALL definition
      # types, which Schema enforces.
      class InvalidName < ArgumentError; end

      attr_reader :name, :asserted

      def initialize(name, asserted = {})
        @name = name.to_s
        raise InvalidName, "an element name cannot be empty" if @name.empty?

        @asserted = normalize(asserted).freeze
        freeze
      end

      # The value written for a metaslot, or nil. Accepts either the metamodel
      # name or the YAML alias -- `type_uri` and `uri` reach the same value.
      def [](metaslot)
        key = metaslot.to_s
        @asserted.fetch(key) do
          @asserted[Metamodel::SLOTS[key]&.yaml_key || key]
        end
      end

      # Whether a metaslot was assigned at all -- distinct from its value, which
      # matters for the boolean metaslots where "unset" and "false" mean
      # different things (`inlined` unset is derivable; `inlined: false` is a
      # decision).
      #
      # NOT named `key?`: SlotDefinition#key? answers the metamodel's `key` slot,
      # and one of the two had to give way. The generic predicate did.
      def assigned?(metaslot) = !self[metaslot].nil?

      # Every metaslot this element assigns that the metamodel does not define.
      # 05validation.md: "Any schema that assigns slot values not in the
      # metamodel is invalid." Extension belongs in `annotations`.
      def unknown_metaslots
        @asserted.keys.reject { |k| Metamodel::SLOTS.key?(Metamodel.metaslot_for_yaml_key(k)) }
      end

      # Assignments that exist in the metamodel but that the specification says
      # nothing about -- description, comments, examples, and the other ~94.
      # Useful documentation; no normative weight.
      def non_normative_assignments
        @asserted.keys.filter_map do |k|
          ms = Metamodel::SLOTS[Metamodel.metaslot_for_yaml_key(k)]
          ms&.name if ms && !ms.normative?
        end
      end

      # is_a and mixins as written, normalized to a list of names. This is P(e)
      # minus the builtin `Any` -- see Derivation.parents, which adds it.
      def is_a = self["is_a"]

      def mixins = Array(self["mixins"]).map(&:to_s)

      def abstract? = self["abstract"] == true
      def mixin? = self["mixin"] == true

      # meta.yaml gives `deprecated` range `string`, not `boolean`. A deprecated
      # element carries the reason as its value. 05validation.md's deprecation
      # checks compare `deprecated=True`, which no valid schema can satisfy; the
      # reading applied here is presence of a non-empty value.
      def deprecated? = !to_s_or_nil(self["deprecated"]).nil?

      def deprecation_reason = to_s_or_nil(self["deprecated"])

      def description = self["description"]

      def annotations = self["annotations"] || {}

      def metatype = self.class.name.split("::").last

      def to_s = @name
      def inspect = "#<#{self.class.name} #{@name.inspect}>"

      def ==(other) = other.class == self.class && other.name == @name && other.asserted == @asserted
      alias eql? ==
      def hash = [self.class, @name, @asserted].hash

      private

      def normalize(hash)
        return {} if hash.nil?

        hash.to_h { |k, v| [k.to_s, v] }
      end

      def to_s_or_nil(value)
        return nil if value.nil?
        return nil if value == false

        s = value.to_s
        s.empty? ? nil : s
      end
    end
  end
end
