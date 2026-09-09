# frozen_string_literal: true

module Vv
  module Linkml
    # What the LinkML specification, as read, does not say.
    #
    # Every entry is a gap in the document -- a function used and never defined,
    # a metaslot referenced that is not in the metamodel, a section with a
    # heading and no body -- located precisely enough that a reader can check it.
    # None of them are opinions about LinkML's design.
    #
    # They are here because this gem had to do *something* at each one, and a
    # library that silently picks an interpretation is indistinguishable from a
    # library that implements a standard. Each Gap names what we do instead, and
    # the affected code points back here.
    #
    # The reference implementation resolves all of these. That is the point: the
    # difference between "LinkML says" and "the Python implementation does" is a
    # real difference, and only one of the two is portable.
    module Unspecified
      # `where` is a specification file and, where it is a single site, a line
      # number in the copy read on 2026-09-08.
      Gap = Struct.new(:key, :where, :what, :interpretation, keyword_init: true) do
        def to_s = "#{key} (#{where}): #{what}"
      end

      GAPS = {
        inlined_as_dict: Gap.new(
          key: :inlined_as_dict,
          where: "04derived-schemas.md AddMissingValues; 06mapping.md \"Collection Forms\"",
          what: "Both procedures are written in terms of `s.inlined_as_dict`, and " \
                "06mapping.md also uses `s.inlined_as_expanded_dict`. Neither " \
                "metaslot exists in meta.yaml. The metamodel has `inlined`, " \
                "`inlined_as_list` and `inlined_as_simple_dict`. Read literally, " \
                "part 6's entire collection-form decision procedure has no input.",
          interpretation: "\"inlined as a dict\" is read as `inlined && !inlined_as_list`, " \
                          "which is how the two real metaslots partition the inlined case. " \
                          "See SlotDefinition#inlined_as_dict?."
        ),

        pk_undefined: Gap.new(
          key: :pk_undefined,
          where: "04derived-schemas.md:348; 06mapping.md:234",
          what: "`PK()` is used twice and defined nowhere in the specification. " \
                "It decides whether a slot is inlined and how a generated class " \
                "is named.",
          interpretation: "PK(c) is the class's identifier slot, or failing that its key " \
                          "slot, taken over A*(c). See DerivedSchema#primary_key."
        ),

        safe_functions: Gap.new(
          key: :safe_functions,
          where: "04derived-schemas.md \"Function: Element CURIEs and URIs\", lines 230-234",
          what: "`Safe`, `SafeCamel` and `SafeSnake` appear only in the Element URI " \
                "table and are never defined. They determine every derived " \
                "class_uri, slot_uri, type uri and enum_uri in every LinkML schema.",
          interpretation: "SafeCamel uppercases the first letter of each separator-delimited " \
                          "part and joins (an already-CamelCase name survives unchanged); " \
                          "SafeSnake breaks CamelCase boundaries and lowercases; Safe " \
                          "percent-encodes everything outside RFC 3986's unreserved set. " \
                          "See Vv::Linkml::Curie."
        ),

        combine_pattern: Gap.new(
          key: :combine_pattern,
          where: "04derived-schemas.md CombineSlotsMetaslots table, `.name == pattern` row",
          what: "The table delegates the `pattern` metaslot to `CombinePattern(v1,v2)`, " \
                "which is never defined. Two regular expressions have no general " \
                "combination that is itself a regular expression.",
          interpretation: "Precedence applies -- the higher-precedence pattern is kept -- " \
                          "and the discarded pattern is named in the induced slot's `notes`."
        ),

        range_intersection: Gap.new(
          key: :range_intersection,
          where: "04derived-schemas.md CombineSlotsMetaslots table, `.name == range` row",
          what: "Combining two ranges yields `A*(r1) ∩ A*(r2)`, a set. `range` has " \
                "cardinality 0..1. The specification gives no rule for choosing a " \
                "member of the intersection.",
          interpretation: "When one range is an ancestor of the other, the more specific one " \
                          "is taken -- that answer is unambiguous. Otherwise precedence " \
                          "applies and the conflict is named in `notes`."
        ),

        add_missing_values_target: Gap.new(
          key: :add_missing_values_target,
          where: "04derived-schemas.md AddMissingValues table",
          what: "`AddMissingValues(s, c)` is passed the CONTAINING class and the rule " \
                "`PK(c)=None => s.inlined=True` reads on it. But `inlined` describes " \
                "how the slot's RANGE is serialized, not its domain.",
          interpretation: "The rule is applied to the range class. meta.yaml's own comment " \
                          "on `inlined` -- \"classes without keys or identifiers are " \
                          "necessarily inlined as lists\" -- is about the range, which is " \
                          "the reading that makes the rule mean anything."
        ),

        alias_seeding: Gap.new(
          key: :alias_seeding,
          where: "04derived-schemas.md DerivedSlot pseudocode",
          what: "DerivedSlot seeds `d = SlotDefinition(name=s, alias=s)` before any " \
                "combination, and `d` has precedence over everything combined into " \
                "it. Under a literal reading a declared `alias:` can never survive " \
                "-- which contradicts the metaslot's own definition, \"If present, " \
                "this is used instead of the actual slot name\".",
          interpretation: "The alias is applied as a fallback after combination instead of " \
                          "as a seed, so a declared alias wins. This departs from the " \
                          "pseudocode as printed and matches the metaslot's stated meaning."
        ),

        apply_slot_usage_pseudocode: Gap.new(
          key: :apply_slot_usage_pseudocode,
          where: "04derived-schemas.md ApplySlotUsage",
          what: "The pseudocode reads `for s' in { c.slot_usage, c.attributes}: " \
                "s' = CombineSlots(d, s')` -- it iterates over the whole maps " \
                "rather than the entry for slot `s`, and assigns the result to the " \
                "loop variable, discarding it. As written the function has no effect.",
          interpretation: "The evident intent: look up entry `s` in c.slot_usage and " \
                          "c.attributes and combine each into `d`, with `d` keeping " \
                          "precedence. Mixins are visited before is_a, which the " \
                          "pseudocode's iteration order does specify."
        ),

        recommended_check: Gap.new(
          key: :recommended_check,
          where: "05validation.md \"Core checks\" table",
          what: "The `Recommended` check's fail condition is printed as " \
                "`<slot>.required=True` -- identical to the `Required` check above " \
                "it. As printed, `recommended` is never consulted by any check.",
          interpretation: "Read as `<slot>.recommended=True`, at severity WARNING per the " \
                          "\"Types of checks\" table."
        ),

        deprecated_is_a_string: Gap.new(
          key: :deprecated_is_a_string,
          where: "05validation.md \"Deprecation checks\" table",
          what: "Every deprecation check compares `deprecated=True`. In meta.yaml " \
                "`deprecated` has range `string` -- it holds the reason. No valid " \
                "schema can satisfy the condition as printed.",
          interpretation: "An element is deprecated when `deprecated` has a non-empty value."
        ),

        empty_sections: Gap.new(
          key: :empty_sections,
          where: "05validation.md \"Rules\", \"Uniqueness checks\", " \
                 "\"Classification Rule evaluation\", \"Inference of new values\"; " \
                 "04derived-schemas.md \"Rule: Derived Permissible Values\"",
          what: "Five sections have headings and no content. The last reads, in full, " \
                "`TODO`. Between them they cover class rules, unique_keys, " \
                "classification rules, value inference and derived permissible values.",
          interpretation: "None of these are implemented, and a Validator report says so " \
                          "in `skipped` rather than omitting them. A schema whose " \
                          "constraints live entirely in `rules` gets an empty report from " \
                          "this gem, and the report is explicit that it is empty for that " \
                          "reason."
        ),

        type_instance_operator: Gap.new(
          key: :type_instance_operator,
          where: "06mapping.md \"Mapping to JSON: Overview\" translation table",
          what: "Rows read `<TypeDefinitionName>&<StringValue>`. Part 2's grammar is " \
                "`InstanceOfType := TypeDefinitionName '^' AtomicValue`; `&` is the " \
                "reference operator, whose left side is a ClassDefinitionName.",
          interpretation: "Read as `^`, per part 2's grammar, which is normative for the " \
                          "instance model."
        ),

        spec_type_list: Gap.new(
          key: :spec_type_list,
          where: "03schemas.md \"Default Types\"",
          what: "The list gives 14 of the 19 types in types.yaml -- omitting curie, " \
                "date_or_datetime, jsonpointer, jsonpath and sparqlpath -- and " \
                "prints all of them capitalised, though types.yaml notes on every " \
                "type that the lower case name is the one used when authoring.",
          interpretation: "Vv::Linkml::Types is built from types.yaml. Types.miscased " \
                          "catches the capitalised form, which otherwise fails silently: " \
                          "an unresolvable range is not an error in LinkML, it just falls " \
                          "through to default_range."
        ),

        draft_status: Gap.new(
          key: :draft_status,
          where: "00preamble.md \"Status of this specification\"",
          what: "\"This is a draft specification open from comments to all.\" LinkML " \
                "is not issued by a standards body and the document has no " \
                "Recommendation-equivalent status.",
          interpretation: "Reported in Vv::Linkml::SPEC[:status] rather than in a footnote."
        )
      }.freeze

      def self.[](key) = GAPS[key.to_sym]

      def self.keys = GAPS.keys

      def self.all = GAPS.values

      # Gaps that affect a particular area, for the caller who wants to know
      # what is soft about a result they just got.
      def self.affecting(area)
        case area.to_sym
        when :derivation
          GAPS.values_at(:inlined_as_dict, :pk_undefined, :safe_functions,
                         :combine_pattern, :range_intersection,
                         :add_missing_values_target, :alias_seeding,
                         :apply_slot_usage_pseudocode, :empty_sections)
        when :validation
          GAPS.values_at(:recommended_check, :deprecated_is_a_string, :empty_sections)
        when :types
          GAPS.values_at(:spec_type_list)
        when :mapping
          GAPS.values_at(:inlined_as_dict, :type_instance_operator, :safe_functions)
        else
          []
        end
      end

      def self.report
        GAPS.values.map(&:to_s)
      end
    end
  end
end
