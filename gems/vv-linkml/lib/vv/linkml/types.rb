# frozen_string_literal: true

require_relative "types/table"

module Vv
  module Linkml
    # The LinkML built-in types, read from types.yaml.
    #
    # THERE ARE 19 OF THEM AND THE SPECIFICATION LISTS 14, UNDER NAMES THAT DO
    # NOT WORK.
    #
    # 03schemas.md's "Default Types" section prints a list beginning "Boolean
    # (Bool)", "Date (XSDDate)", "Datetime (XSDDateTime)". Two things are wrong
    # with using that list as the type table:
    #
    #   1. Five types are missing from it: curie, date_or_datetime, jsonpointer,
    #      jsonpath, sparqlpath.
    #
    #   2. The capitalised names are not the names you write. types.yaml attaches
    #      the same note to every single type -- "If you are authoring schemas in
    #      LinkML YAML, the type is referenced with the lower case <name>". A
    #      slot written `range: Boolean` does not resolve to the boolean type. It
    #      resolves to nothing, and the schema's `default_range` quietly takes
    #      over, which for a schema that never set one is `string`. The slot
    #      validates strings and nobody is told.
    #
    # That is the failure this module exists to make loud. `Types.lookup` is
    # case-sensitive on purpose, and `Types.miscased` names the trap when a
    # caller hands over `Boolean`.
    module Types
      SOURCE = "LinkML types.yaml, linkml/linkml-model main branch, " \
               "sha256 1c79b264…8743fe00, read 2026-09-08"

      # The section of 03schemas.md that gets this wrong, quoted for the reader
      # who wants to check.
      SPEC_LIST_IS_INCOMPLETE =
        "03schemas.md \"Default Types\" lists 14 of the 19 types in types.yaml, " \
        "omitting curie, date_or_datetime, jsonpointer, jsonpath and sparqlpath, " \
        "and prints all of them capitalised. types.yaml notes on every type that " \
        "the lower case name is the one used when authoring schemas."

      class Unknown < ArgumentError; end

      # One built-in type. `base` and `repr` are Python names -- meta.yaml
      # describes `base` as "python base type that implements this type
      # definition" -- and are carried because they are in the metamodel, not
      # because a Ruby consumer should act on them.
      Type = Struct.new(:name, :curie, :uri, :base, :repr, :description,
                        :conforms_to, keyword_init: true) do
        def to_s = name

        # The XSD (or shex, for the two identifier types) datatype the type maps
        # to. This is what part 5's Datatype check compares against.
        def xsd? = uri.start_with?("http://www.w3.org/2001/XMLSchema#")

        def numeric? = %w[integer float double decimal].include?(name)
        def temporal? = %w[date datetime time date_or_datetime].include?(name)

        # objectidentifier and nodeidentifier map to shex:iri and
        # shex:nonLiteral, not to an XSD datatype. In RDF they are nodes, not
        # literals, which is why part 5 gives them a NodeKind check rather than
        # a Datatype check.
        def node? = uri.start_with?("http://www.w3.org/ns/shex#")
      end

      ALL = BUILTIN.each_with_object({}) do |(name, row), h|
        h[name] = Type.new(name: name, curie: row[0], uri: row[1], base: row[2],
                           repr: row[3], description: row[4],
                           conforms_to: row[5]).freeze
      end.freeze

      # All 19 names, in types.yaml order.
      def self.names = ALL.keys

      def self.[](name) = ALL[name.to_s]

      def self.builtin?(name) = ALL.key?(name.to_s)

      def self.lookup!(name)
        name = name.to_s
        found = ALL[name]
        return found if found

        raise Unknown, unknown_message(name)
      end

      # If `name` is a built-in type under different capitalisation, returns the
      # correct lowercase name; otherwise nil.
      #
      # This exists because the miscased form is not an error anywhere in the
      # pipeline -- LinkML treats an unresolvable range as "fall back to
      # default_range" -- so the only place it can be caught is here.
      def self.miscased(name)
        name = name.to_s
        return nil if ALL.key?(name)

        ALL.keys.find { |n| n.casecmp?(name) }
      end

      # The 14 names 03schemas.md prints, and the 5 it omits. Kept as data so
      # the claim in the module comment is checkable rather than asserted.
      SPEC_LISTED = %w[
        boolean date datetime decimal double float integer ncname nodeidentifier
        objectidentifier string time uri uriorcurie
      ].freeze

      def self.omitted_from_spec_list = names - SPEC_LISTED

      def self.unknown_message(name)
        fix = miscased(name)
        if fix
          "#{name.inspect} is not a LinkML built-in type, but #{fix.inspect} is. " \
          "types.yaml notes on every type that the lower case name is the one " \
          "used when authoring schemas. A schema that writes `range: #{name}` " \
          "does not raise -- the range fails to resolve and default_range takes " \
          "over silently."
        else
          "#{name.inspect} is not one of the #{ALL.size} LinkML built-in types: " \
          "#{names.join(', ')}. (#{SPEC_LIST_IS_INCOMPLETE})"
        end
      end
    end
  end
end
