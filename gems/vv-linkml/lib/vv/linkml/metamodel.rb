# frozen_string_literal: true

require_relative "metamodel/tables"

module Vv
  module Linkml
    # The LinkML metamodel: the metaslots and metaclasses a schema may use, read
    # from `meta.yaml` rather than from prose about it.
    #
    # THE POINT OF THIS MODULE IS THE `normative?` PREDICATE.
    #
    # LinkML's specification says so itself (03schemas.md, "The LinkML
    # Metamodel"): it specifies "the *normative elements* necessary to specify
    # the behavior of LinkML schemas", and "schemas may have additional elements
    # provided in the metamodel". The normative part is marked in meta.yaml as
    # membership in the `SpecificationSubset`.
    #
    # Counted from meta.yaml: 122 of 216 metaslots and 15 of 40 metaclasses are
    # in that subset. Roughly 44% of the metamodel is outside the specification.
    # `description`, `title`, `comments`, `examples`, `see_also` and `deprecated`
    # are all real metaslots that real schemas use, and a conforming
    # implementation is free to ignore every one of them.
    #
    # So "the metamodel has it" and "the specification requires it" are two
    # different claims, and a model that collapses them reports guarantees LinkML
    # does not make. Everything here answers one or the other, never both at once.
    module Metamodel
      SOURCE = "LinkML metamodel, linkml/linkml-model meta.yaml @ 35c91fb01382, " \
               "sha256 7f9e39fb…56b96673, read 2026-09-08"

      # meta.yaml's own `metamodel_version` key. Not the linkml-model release
      # tag and not the reference implementation's version, though at read time
      # all three were near 1.11.
      VERSION_READ = "1.11.0"

      class UnknownMetaslot < ArgumentError; end

      # One metaslot as meta.yaml declares it.
      Metaslot = Struct.new(:name, :normative, :inheritable, :multivalued, :range,
                            :yaml_alias, keyword_init: true) do
        # In the SpecificationSubset -- i.e. the specification actually says
        # something about this. See the module comment.
        def normative? = normative == true

        # meta.yaml spells this `inherited: true`. It is the flag DerivedSlot
        # consults when propagating values along the slot `is_a`/`mixins` chain,
        # and only 40 of the 216 metaslots carry it. `description` does not: a
        # slot that inherits from a documented parent inherits no documentation.
        def inheritable? = inheritable == true

        def multivalued? = multivalued == true

        # The key you actually write in schema YAML. Ten metaslots differ from
        # their metamodel name -- `slot_definitions` is written `slots`, and
        # `type_uri` is written `uri`. Reading the normative tables in
        # 03schemas.md as if they listed YAML keys produces schemas that do not
        # load.
        def yaml_key = yaml_alias || name

        def aliased? = !yaml_alias.nil?
      end

      # One metaclass as meta.yaml declares it.
      Metaclass = Struct.new(:name, :normative, :abstract, :mixin, :is_a,
                             keyword_init: true) do
        def normative? = normative == true
        def abstract? = abstract == true
        def mixin? = mixin == true
      end

      SLOTS = METASLOTS.each_with_object({}) do |(name, row), h|
        h[name] = Metaslot.new(name: name, normative: row[0], inheritable: row[1],
                               multivalued: row[2], range: row[3],
                               yaml_alias: row[4]).freeze
      end.freeze

      CLASSES = METACLASSES.each_with_object({}) do |(name, row), h|
        h[name] = Metaclass.new(name: name, normative: row[0], abstract: row[1],
                                mixin: row[2], is_a: row[3]).freeze
      end.freeze

      # Every metaslot name, sorted. 216 of them.
      def self.slot_names = SLOTS.keys

      def self.class_names = CLASSES.keys

      def self.slot(name) = SLOTS[name.to_s]

      def self.metaclass(name) = CLASSES[name.to_s]

      def self.slot!(name)
        SLOTS[name.to_s] or
          raise UnknownMetaslot,
                "#{name} is not a metaslot in LinkML metamodel #{VERSION_READ}. " \
                "A schema assigning it is invalid (05validation.md: \"Any schema " \
                "that assigns slot values not in the metamodel is invalid\"). If " \
                "you meant to attach your own metadata, use `annotations`."
      end

      # Does the specification say anything about this metaslot? Answers false
      # for the ~94 metaslots that exist only in the metamodel.
      def self.normative?(name) = slot!(name).normative?

      # Does DerivedSlot propagate this metaslot along the slot ancestry?
      def self.inheritable?(name) = slot!(name).inheritable?

      def self.multivalued?(name) = slot!(name).multivalued?

      def self.range_of(name) = slot!(name).range

      def self.boolean?(name) = slot!(name).range == "boolean"

      # The 40 metaslots DerivedSlot propagates. Everything else stops at the
      # slot where it was written.
      def self.inheritable_slots = SLOTS.values.select(&:inheritable?).map(&:name)

      def self.normative_slots = SLOTS.values.select(&:normative?).map(&:name)

      def self.non_normative_slots = SLOTS.values.reject(&:normative?).map(&:name)

      def self.normative_classes = CLASSES.values.select(&:normative?).map(&:name)

      # The ten metaslots whose YAML key differs from their metamodel name,
      # as { metaslot_name => yaml_key }.
      def self.aliases
        SLOTS.values.select(&:aliased?).to_h { |s| [s.name, s.yaml_key] }
      end

      # Reverse of `aliases`: given a key seen in schema YAML, the metaslot it
      # names. Returns the input unchanged when there is no alias, which is the
      # common case.
      def self.metaslot_for_yaml_key(key)
        key = key.to_s
        aliases.key(key) || key
      end

      # A one-line census, for when someone asks how much of LinkML is actually
      # specified.
      def self.census
        {
          metaslots: SLOTS.size,
          normative_metaslots: normative_slots.size,
          inheritable_metaslots: inheritable_slots.size,
          metaclasses: CLASSES.size,
          normative_metaclasses: normative_classes.size,
          metamodel_version: VERSION_READ,
          source: SOURCE
        }.freeze
      end
    end
  end
end
