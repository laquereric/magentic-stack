# frozen_string_literal: true

require "set"

require_relative "schema"
require_relative "metamodel"
require_relative "curie"
require_relative "unspecified"

module Vv
  module Linkml
    # A slot as it applies inside one class: the result of DerivedSlot(m, s, c).
    #
    # Carries where each value came from. `provenance` maps metaslot name to one
    # of :slot_usage, :attribute, :top_level_slot, :slot_ancestor, :default_range,
    # :add_missing_values, :seeded -- so "why is this required?" has an answer
    # that is not "read the schema and its four ancestors".
    class InducedSlot < SlotDefinition
      attr_reader :owner, :provenance, :notes

      def initialize(name, asserted, owner:, provenance: {}, notes: [])
        @owner = owner.to_s
        @provenance = provenance.transform_keys(&:to_s).freeze
        @notes = notes.freeze
        super(name, asserted)
      end

      def source_of(metaslot) = @provenance[metaslot.to_s]

      # True when a value was written somewhere rather than defaulted in.
      def asserted?(metaslot)
        src = source_of(metaslot)
        !src.nil? && !%i[default_range add_missing_values seeded].include?(src)
      end

      def inspect = "#<Vv::Linkml::InducedSlot #{@owner}.#{name} range=#{range.inspect}>"
    end

    # A derived (induced) schema: the import closure combined, every class's
    # applicable slots derived, every element URI resolved.
    #
    # `complete?` is the field to read first. A derived schema built over
    # unresolved imports, or over an enum whose values come from an external
    # ontology, is missing things -- and a validator run against it will report
    # no errors for constraints it never saw. `gaps` says what is missing.
    class DerivedSchema
      attr_reader :schema, :slots, :uris, :gaps, :sources

      def initialize(schema:, slots:, uris:, gaps:, sources:)
        @schema = schema
        @slots = slots.freeze
        @uris = uris.freeze
        @gaps = gaps.freeze
        @sources = sources.freeze
        freeze
      end

      # No unresolved imports, no dynamic enums, no unresolvable ranges. False
      # does not mean broken; it means a clean validation report from this
      # schema is not evidence of a clean schema.
      def complete? = @gaps.empty?

      # Induced slots for a class, keyed by the slot's alias -- which is the key
      # that appears in instance data.
      def slots_for(class_name) = @slots[class_name.to_s] || {}

      def slot_for(class_name, slot_name)
        slots_for(class_name)[slot_name.to_s]
      end

      # The identifier or key slot of a class, or nil. The function the
      # specification calls PK() and never defines.
      def primary_key(class_name)
        slots_for(class_name).values.find(&:identifier?) ||
          slots_for(class_name).values.find(&:key?)
      end

      def uri_for(element_name) = @uris[element_name.to_s]

      def class_names = @slots.keys

      def to_s = "#<Vv::Linkml::DerivedSchema #{@schema.name.inspect} complete=#{complete?}>"
      alias inspect to_s
    end

    # A derived URI for a schema element.
    class ElementUri
      attr_reader :element, :metatype, :curie, :uri, :derived

      def initialize(element:, metatype:, curie:, uri:, derived:)
        @element = element
        @metatype = metatype
        @curie = curie
        @uri = uri
        @derived = derived
        freeze
      end

      # True when the schema did not write this URI and derivation supplied it
      # from default_prefix and the element name.
      def derived? = @derived == true

      # False when the CURIE has no expansion -- default_prefix names no entry
      # in the prefix map. The CURIE still exists and still looks fine.
      def resolvable? = !@uri.nil?

      def to_s = @uri || @curie.to_s
      def inspect = "#<Vv::Linkml::ElementUri #{@element} #{@curie.inspect}#{' derived' if derived?}>"
    end

    # 04derived-schemas.md, implemented.
    #
    # The chapter defines the functions L, K, URI/CURIE, Resolve, C (closure),
    # P (parents), A/A* (ancestors), I (imports closure) and ApplicableSlots,
    # and the algorithms CombineSlots, CombineSchemas and DerivedSlot. Those
    # names are kept below, because the point of transcribing a specified
    # procedure is that a reader can check it line for line.
    #
    # Where the chapter is underdetermined this class does something anyway --
    # it has to -- and records what, in Unspecified::GAPS and in each induced
    # slot's `notes`. The three that bite hardest:
    #
    #   * `AddMissingValues` keys on `s.inlined_as_dict`, a metaslot that is not
    #     in meta.yaml.
    #   * `PK()` is used and never defined.
    #   * `SafeCamel`/`SafeSnake` decide every derived class_uri and slot_uri in
    #     every LinkML schema, and are never defined.
    class Derivation
      class CircularInheritance < StandardError; end
      class ImportUnresolved < StandardError; end

      # The builtin ClassDefinition that P(e) unions into every element's
      # parents: "Parents itself is the union of is_a and mixins, plus the
      # builtin ClassDefinition `Any`". meta.yaml defines it as class `Anything`
      # with class_uri `linkml:Any`.
      ANY = "Any"

      attr_reader :schema

      def initialize(schema)
        @schema = schema
        @memo = {}
      end

      def self.for(schema) = new(schema)

      # ---------------------------------------------------------------
      # Functions
      # ---------------------------------------------------------------

      # L(v) -- normalize to a list. None => [], a list => itself, anything else
      # => a one-element list.
      def self.normalize_list(value)
        case value
        when nil then []
        when Array then value
        else [value]
        end
      end

      # K(v) -- the identifier value of an instance. In the metamodel the
      # identifier is always `name`, which is what the chapter says; for
      # arbitrary instances the identifier slot has to be looked up, which is
      # what DerivedSchema#primary_key is for.
      def self.identifier_value(instance, key_slot = "name")
        return nil unless instance.is_a?(Hash)

        instance[key_slot] || instance[key_slot.to_sym]
      end

      # P(e) = L(e.is_a) ∪ L(e.mixins) ∪ { Any }
      #
      # `Any` is included because the chapter says so. It is not a class any
      # schema defines, so it is filtered out of ancestor walks; it exists so
      # that A*(e) is never empty.
      def parents(element)
        return [] if element.nil?

        ([element.is_a] + element.mixins).compact.map(&:to_s) + [ANY]
      end

      # A(e) = C(e, P) -- the transitive closure of parents, excluding e.
      def ancestors(element, kind: nil)
        return [] if element.nil?

        walk(element, kind: kind, reflexive: false)
      end

      # A*(e) = C*(e, P) -- ancestors including e.
      def reflexive_ancestors(element, kind: nil)
        return [] if element.nil?

        walk(element, kind: kind, reflexive: true)
      end

      # ApplicableSlots(c) = ∪ over c' in A*(c) of DirectSlots(c')
      # DirectSlots(c) = L(c.slots) ∪ L(c.attributes)
      #
      # These are the slot NAMES valid for an instance of c. What each one means
      # in c's context is DerivedSlot's answer, not this one.
      def applicable_slots(class_name)
        cls = @schema.class_def(class_name)
        return [] if cls.nil?

        reflexive_ancestors(cls, kind: :class).flat_map do |n|
          c = @schema.class_def(n)
          c ? c.direct_slot_names : []
        end.uniq
      end

      # ---------------------------------------------------------------
      # CombineSlots
      # ---------------------------------------------------------------

      # CombineSlotsMetaslots(ms, v1, v2), transcribed from the table in
      # 04derived-schemas.md. s1 has precedence over s2, and the rows are matched
      # in the order printed -- `range` is matched by NAME before the generic
      # `multivalued` and `boolean` rows, which is why the order below is not
      # rearranged for tidiness.
      #
      # Returns [value, note] where note is nil unless the combination was
      # underdetermined.
      def combine_metaslot(metaslot, v1, v2)
        return [v1, nil] if v1 == v2
        return [v2, nil] if v1.nil?
        return [v1, nil] if v2.nil?

        ms = Metamodel::SLOTS[metaslot.to_s]

        case metaslot.to_s
        when "maximum_value" then return [[v1, v2].min, nil]
        when "minimum_value" then return [[v1, v2].max, nil]
        when "pattern"       then return combine_pattern(v1, v2)
        when "range"         then return combine_range(v1, v2)
        end

        return [(Derivation.normalize_list(v1) | Derivation.normalize_list(v2)), nil] if ms&.multivalued?
        return [v1 || v2, nil] if ms&.range == "boolean"

        [v1, nil]
      end

      # CombineSlots(s1, s2). s1 has precedence.
      #
      # Returns [merged_hash, notes, changed_keys] -- `changed_keys` being the
      # metaslots s2 actually contributed, which is what provenance tracking
      # needs and what a caller comparing two slots usually wants.
      def combine_slots(h1, h2)
        h1 = stringify(h1)
        h2 = stringify(h2)
        notes = []
        merged = {}
        changed = []

        (h1.keys | h2.keys).each do |key|
          value, note = combine_metaslot(Metamodel.metaslot_for_yaml_key(key), h1[key], h2[key])
          notes << note if note
          next if value.nil?

          merged[key] = value
          changed << key if h1[key].nil? || value != h1[key]
        end

        [merged, notes, changed]
      end

      # ---------------------------------------------------------------
      # DerivedSlot
      # ---------------------------------------------------------------

      # DerivedSlot(m, s, c) -- the slot `s` as it applies inside class `c`.
      #
      # The chapter's pseudocode, in order:
      #
      #   d = SlotDefinition(name=s, alias=s)
      #   ApplySlotUsage(d, s, c)
      #   if s in m.slots: d = CombineSlots(d, m.slots[s])
      #                    for s' in A(s): propagate inheritable metaslots
      #   AddMissingValues(d, c)
      #
      # One deliberate departure. The pseudocode seeds `d` with `alias=s` before
      # any combination, and `d` has precedence -- so under a literal reading a
      # declared `alias:` can never survive, which contradicts the metaslot's own
      # definition ("If present, this is used instead of the actual slot name").
      # Here the alias is applied as a fallback at the end instead, so a declared
      # alias wins. Recorded as Unspecified::GAPS[:alias_seeding].
      def derived_slot(slot_name, class_name)
        slot_name = slot_name.to_s
        class_name = class_name.to_s
        acc = { hash: {}, provenance: {}, notes: [] }

        apply_slot_usage(acc, slot_name, class_name, Set.new)

        top = @schema.slot(slot_name)
        if top
          absorb(acc, top.asserted, :top_level_slot)

          ancestors(top, kind: :slot).each do |ancestor_name|
            anc = @schema.slot(ancestor_name)
            next if anc.nil?

            inheritable = anc.asserted.select do |k, _|
              Metamodel::SLOTS[Metamodel.metaslot_for_yaml_key(k)]&.inheritable?
            end
            absorb(acc, inheritable, :slot_ancestor)
          end
        end

        apply_default_range(acc)
        add_missing_values(acc, class_name)

        acc[:hash]["alias"] ||= slot_name
        acc[:provenance]["alias"] ||= :seeded

        InducedSlot.new(slot_name, acc[:hash], owner: class_name,
                                               provenance: acc[:provenance], notes: acc[:notes])
      end

      # Every applicable slot of a class, derived, keyed by the alias that
      # appears in instance data.
      def induced_slots(class_name)
        applicable_slots(class_name).to_h do |s|
          d = derived_slot(s, class_name)
          [d.alias_name, d]
        end
      end

      # ---------------------------------------------------------------
      # Element URIs
      # ---------------------------------------------------------------

      # ModelURI(e) -- `<default_prefix>:<SafeCamel|SafeSnake(e.name)>`.
      #
      # Returns nil when the schema has no default_prefix, because there is then
      # nothing to build a CURIE from and a bare name is not one.
      def model_uri(element_name, metatype)
        prefix = @schema.default_prefix
        return nil if prefix.nil?

        local =
          case metatype
          when :slot then Curie.safe_snake(element_name)
          else Curie.safe_camel(element_name)
          end

        "#{prefix}:#{local}"
      end

      # The element URI: the declared one if there is one, otherwise the model
      # URI. 04derived-schemas.md: "If the element URI slot is not set, then the
      # model URI is used as the element URI."
      def element_uri(element_name)
        name = element_name.to_s
        metatype, declared = declared_uri(name)
        return nil if metatype.nil?

        curie = declared || model_uri(name, metatype)
        return nil if curie.nil?

        ElementUri.new(element: name, metatype: metatype, curie: curie,
                       uri: @schema.expanded_prefixes.expand(curie),
                       derived: declared.nil?)
      end

      # ---------------------------------------------------------------
      # Permissible values
      # ---------------------------------------------------------------

      # PVs(e), for the part that can be computed from the schema alone.
      #
      # Returns [values, unresolved] where `unresolved` names the constructs that
      # need something this gem does not have -- `reachable_from` and `matches`
      # resolve against an external ontology, and `concepts` is a list of
      # identifiers to be expanded elsewhere. An empty `unresolved` means the
      # value set is the whole value set.
      def permissible_values(enum_name, seen = Set.new)
        enum = @schema.enum(enum_name)
        return [[], ["no enum named #{enum_name}"]] if enum.nil?
        return [[], ["circular enum inheritance at #{enum_name}"]] if seen.include?(enum.name)

        seen = seen + [enum.name]
        values = enum.texts.dup
        unresolved = []

        enum.inherits.each do |parent|
          v, u = permissible_values(parent, seen)
          values |= v
          unresolved.concat(u)
        end

        enum.include_exprs.each do |expr|
          literals, note = enum_expression_values(expr)
          values |= literals
          unresolved << note if note
        end

        enum.minus.each do |expr|
          literals, note = enum_expression_values(expr)
          values -= literals
          unresolved << note if note
        end

        if enum.reachable_from
          unresolved << "reachable_from resolves against an external ontology " \
                        "(#{enum.reachable_from.inspect}); 04derived-schemas.md's " \
                        "ResolveQuery needs a graph presentation of that resource"
        end
        if enum.matches
          unresolved << "matches resolves against an external vocabulary (#{enum.matches.inspect})"
        end
        unless enum.concepts.empty?
          unresolved << "concepts must be expanded against an external vocabulary " \
                        "(#{enum.concepts.join(', ')})"
        end

        [values.uniq, unresolved.uniq]
      end

      # ---------------------------------------------------------------
      # Whole-schema derivation
      # ---------------------------------------------------------------

      # Derives the whole schema. `resolver` is called with each import name and
      # must return a Schema or nil; the built-in resolver knows `linkml:types`
      # and nothing else.
      #
      # Unresolved imports do not raise. They are recorded in `gaps`, and
      # `complete?` goes false -- because the alternative is a derived schema
      # that looks finished and is missing half its classes.
      def derive(resolver: Derivation.default_resolver)
        combined, sources, import_gaps = combine_import_closure(resolver)
        derivation = combined.equal?(@schema) ? self : Derivation.new(combined)

        slots = combined.classes.each_key.to_h do |cname|
          [cname, derivation.induced_slots(cname)]
        end

        uris = combined.elements.each_key.filter_map do |ename|
          u = derivation.element_uri(ename)
          [ename, u] if u
        end.to_h

        gaps = import_gaps.dup
        combined.enums.each_key do |ename|
          _, unresolved = derivation.permissible_values(ename)
          unresolved.each { |u| gaps << "enum #{ename}: #{u}" }
        end
        combined.unresolvable_ranges.each do |slot, range, fix|
          hint = fix ? " (did you mean #{fix.inspect}? see Types.miscased)" : ""
          gaps << "slot #{slot}: range #{range.inspect} resolves to nothing, so " \
                  "default_range takes over silently#{hint}"
        end
        uris.each_value do |u|
          next if u.resolvable?

          gaps << "#{u.element}: CURIE #{u.curie.inspect} has no expansion; " \
                  "default_prefix #{combined.default_prefix.inspect} is not in " \
                  "the prefix map, so this IRI parses and does not resolve"
        end

        DerivedSchema.new(schema: combined, slots: slots, uris: uris,
                          gaps: gaps.uniq, sources: sources)
      end

      # I(m) combined by CombineSchemas. Returns [schema, sources, gaps].
      def combine_import_closure(resolver)
        return [@schema, [@schema.name || @schema.id], []] unless @schema.imports?

        gaps = []
        sources = [@schema.name || @schema.id]
        merged_raw = @schema.raw.dup
        # Schema accepts either key; CombineSchemas writes to `slots`, so
        # normalize first or the originals are shadowed by the imports.
        if merged_raw["slot_definitions"] && !merged_raw["slots"]
          merged_raw["slots"] = merged_raw.delete("slot_definitions")
        end
        queue = @schema.imports.dup
        seen = Set.new

        until queue.empty?
          import_name = queue.shift
          next if seen.include?(import_name)

          seen << import_name

          imported = resolver.call(import_name, @schema)
          if imported.nil?
            gaps << "import #{import_name.inspect} was not resolved; every class, " \
                    "slot, enum and type it defines is absent from the derived schema"
            next
          end

          sources << (imported.name || imported.id || import_name)
          queue.concat(imported.imports)
          merged_raw = combine_schemas(merged_raw, imported)
        end

        [Schema.new(merged_raw, source: @schema.source), sources, gaps]
      end

      # CombineSchemas(m1, m2), for the element collections. The chapter is
      # explicit that a name used in both is an error, not a merge: "if e.id in
      # E2ids: raise Error".
      def combine_schemas(raw1, schema2)
        out = raw1.dup
        {
          "classes" => schema2.classes, "slots" => schema2.slots,
          "enums" => schema2.enums, "types" => schema2.types,
          "subsets" => schema2.subsets
        }.each do |key, table|
          existing = out[key] || {}
          table.each do |name, element|
            if existing.key?(name)
              raise Schema::NameCollision,
                    "#{name.inspect} is defined in both #{raw1['name'] || raw1['id']} " \
                    "and #{schema2.name || schema2.id}. CombineElements in " \
                    "04derived-schemas.md raises on a name present in both inputs; " \
                    "LinkML has no import namespacing to fall back on."
            end
            existing = existing.merge(name => element.asserted)
          end
          out[key] = existing unless existing.empty?
        end
        out["prefixes"] = (schema2.prefixes.map).merge(out["prefixes"] || {})
        out
      end

      # The default import resolver: knows `linkml:types` (and its plain aliases)
      # and refuses everything else by returning nil, which surfaces as a gap
      # rather than as a silently smaller schema.
      def self.default_resolver
        lambda do |import_name, _schema|
          case import_name.to_s
          when "linkml:types", "types", "https://w3id.org/linkml/types"
            builtin_types_schema
          end
        end
      end

      # A Schema standing in for linkml:types, built from the table this gem
      # already carries.
      def self.builtin_types_schema
        @builtin_types_schema ||= Schema.new({
          "id" => "https://w3id.org/linkml/types",
          "name" => "types",
          "default_prefix" => "linkml",
          "default_range" => "string",
          "prefixes" => { "linkml" => "https://w3id.org/linkml/",
                          "xsd" => "http://www.w3.org/2001/XMLSchema#",
                          "shex" => "http://www.w3.org/ns/shex#" },
          "types" => Types::ALL.transform_values do |t|
            { "uri" => t.curie, "base" => t.base, "repr" => t.repr,
              "description" => t.description }.compact
          end
        })
      end

      private

      # ApplySlotUsage(d, s, c). Mixins before is_a, which is the order the
      # chapter prints and the opposite of most object-oriented intuition.
      def apply_slot_usage(acc, slot_name, class_name, seen)
        cls = @schema.class_def(class_name)
        return if cls.nil?

        if seen.include?(cls.name)
          raise CircularInheritance,
                "class #{cls.name} is its own ancestor; A*(c) does not terminate"
        end
        seen = seen + [cls.name]

        usage = cls.slot_usage[slot_name]
        absorb(acc, usage.asserted, :slot_usage) if usage

        attribute = cls.attributes[slot_name]
        absorb(acc, attribute.asserted, :attribute) if attribute

        (cls.mixins + [cls.is_a].compact).each do |parent|
          apply_slot_usage(acc, slot_name, parent.to_s, seen)
        end
      end

      # CombineSlots(acc, incoming) with acc keeping precedence, recording which
      # source supplied each newly-filled metaslot.
      def absorb(acc, incoming, source)
        merged, notes, changed = combine_slots(acc[:hash], incoming)
        acc[:hash] = merged
        acc[:notes].concat(notes)
        changed.each { |k| acc[:provenance][k] = source }
      end

      def stringify(hash)
        return {} if hash.nil?

        hash.to_h { |k, v| [k.to_s, v] }
      end

      # meta.yaml gives `range` `ifabsent: default_range`, and
      # 04derived-schemas.md's "Populate Schema Metadata" rule sets an unset
      # default_range to `string`. Together that is the whole default chain.
      def apply_default_range(acc)
        return if acc[:hash]["range"]

        acc[:hash]["range"] = @schema.default_range
        acc[:provenance]["range"] = :default_range
        return if @schema.default_range_asserted?

        acc[:notes] << "range defaulted to #{Schema::DEFAULT_RANGE_FALLBACK.inspect} " \
                       "by the Populate Schema Metadata rule; the schema never " \
                       "declared a default_range"
      end

      # AddMissingValues(s, c). The chapter's table is two rows:
      #
      #   | s.inlined_as_dict=True | s.inlined=True |
      #   | PK(c)=None             | s.inlined=True |
      #
      # Row 1 keys on a metaslot that is not in meta.yaml. Under the reading in
      # SlotDefinition#inlined_as_dict? it is a tautology, so it does nothing.
      #
      # Row 2 uses PK(), which the specification never defines, and passes the
      # CONTAINING class -- but `inlined` describes how the slot's RANGE is
      # serialized, and meta.yaml's own comment on `inlined` is "classes without
      # keys or identifiers are necessarily inlined as lists". So the rule is
      # applied to the range class, which is the reading that makes it mean
      # anything. Recorded as Unspecified::GAPS[:pk_undefined] and
      # [:add_missing_values_target].
      def add_missing_values(acc, _class_name)
        return if acc[:hash].key?("inlined")

        range_class = @schema.class_def(acc[:hash]["range"])
        return if range_class.nil?

        return if primary_key_slot?(range_class)

        acc[:hash]["inlined"] = true
        acc[:hash]["inlined_as_list"] = true
        acc[:provenance]["inlined"] = :add_missing_values
        acc[:provenance]["inlined_as_list"] = :add_missing_values
        acc[:notes] << "inlined inferred: range class #{range_class.name} has no " \
                       "identifier or key slot, so it cannot be referenced by value " \
                       "and must appear inline (meta.yaml, comment on `inlined`)"
      end

      # PK(c) -- undefined in the specification. Read as: an identifier slot, or
      # failing that a key slot, among the class's applicable slots.
      #
      # This deliberately does NOT go through derived_slot. A schema where class
      # A has a slot ranged on B and B has a slot ranged on A is ordinary, and
      # deriving a slot in order to decide whether to derive a slot would not
      # terminate. So the check reads the asserted definitions -- top-level slot,
      # and every ancestor's attributes and slot_usage -- directly.
      def primary_key_slot?(cls)
        ancestry = reflexive_ancestors(cls, kind: :class).filter_map { |n| @schema.class_def(n) }

        applicable_slots(cls.name).any? do |slot_name|
          candidates = [@schema.slot(slot_name)]
          ancestry.each do |c|
            candidates << c.attributes[slot_name] << c.slot_usage[slot_name]
          end
          candidates.compact.any? { |d| d.identifier? || d.key? }
        end
      end

      # The literal permissible values an AnonymousEnumExpression contributes,
      # plus a note when it contributes more than literals. Returns [values, note].
      def enum_expression_values(expr)
        return [[], nil] unless expr.is_a?(Hash)

        literals = Array(expr["permissible_values"]).map { |v| v.is_a?(Hash) ? v.keys.first.to_s : v.to_s }
        literals = expr["permissible_values"].keys.map(&:to_s) if expr["permissible_values"].is_a?(Hash)

        extras = expr.keys - %w[permissible_values]
        note = unless extras.empty?
                 "an enum expression used #{extras.join(', ')}; only its literal " \
                 "permissible_values were applied"
               end

        [literals, note]
      end

      def declared_uri(name)
        if (c = @schema.class_def(name)) then [:class, c.class_uri]
        elsif (s = @schema.slot(name)) then [:slot, s.slot_uri]
        elsif (e = @schema.enum(name)) then [:enum, e.enum_uri]
        elsif (t = @schema.type(name)) then [:type, t.uri]
        else [nil, nil]
        end
      end

      # CombinePattern(v1, v2) -- used by the combination table and never
      # defined. Two regular expressions have no general combination that is
      # itself a regular expression the caller would recognise, so precedence
      # applies and the discarded pattern is named.
      def combine_pattern(v1, v2)
        [v1, "pattern #{v2.inspect} was discarded in favour of #{v1.inspect}: " \
             "04derived-schemas.md delegates this to CombinePattern(v1,v2), which " \
             "the specification does not define"]
      end

      # range: A*(r1) ∩ A*(r2). The intersection is a SET and `range` is 0..1;
      # the chapter does not say which member to take. When one range is an
      # ancestor of the other the answer is unambiguous -- the more specific one
      # -- and that is what is returned. Otherwise precedence applies and the
      # conflict is named.
      def combine_range(r1, r2)
        a1 = reflexive_ancestors_of_range(r1)
        a2 = reflexive_ancestors_of_range(r2)

        return [r1, nil] if a1.include?(r2.to_s)
        return [r2, nil] if a2.include?(r1.to_s)

        [r1, "ranges #{r1.inspect} and #{r2.inspect} are unrelated; " \
             "04derived-schemas.md gives A*(r1) ∩ A*(r2), a set, for a metaslot " \
             "with cardinality 0..1, and no rule for choosing from it. Took the " \
             "higher-precedence range."]
      end

      def reflexive_ancestors_of_range(name)
        n = name.to_s
        case @schema.range_metatype(n)
        when :class then reflexive_ancestors(@schema.class_def(n), kind: :class)
        when :enum then reflexive_ancestors(@schema.enum(n), kind: :enum)
        when :type then type_ancestors(n)
        else [n]
        end
      end

      # Types inherit through `typeof`, not `is_a` -- a different metaslot with
      # the same job, which A*() as written does not cover.
      def type_ancestors(name)
        chain = []
        current = name.to_s
        while current && !chain.include?(current)
          chain << current
          current = @schema.type(current)&.typeof
        end
        chain
      end

      # C*(e, P) / C(e, P), with a cycle guard. Elements named by is_a or mixins
      # that the schema does not define are kept in the result -- a dangling
      # parent is a structural conformance failure ("Every ClassDefinition
      # reference must be resolvable"), and dropping it hides that.
      def walk(element, kind:, reflexive:)
        out = []
        seen = Set.new
        queue = parents(element).reject { |n| n == ANY }

        until queue.empty?
          name = queue.shift
          next if seen.include?(name)

          seen << name
          out << name
          parent = lookup(name, kind)
          queue.concat(parents(parent).reject { |n| n == ANY }) if parent
        end

        # `element` itself is deliberately NOT pre-seeded into `seen`: with a
        # cycle (A is_a B is_a A) the closure C(e, P) really does contain e, and
        # suppressing it would report the cycle as an ordinary chain.
        reflexive ? ([element.name] + out).uniq : out
      end

      def lookup(name, kind)
        case kind
        when :class then @schema.class_def(name)
        when :slot then @schema.slot(name)
        when :enum then @schema.enum(name)
        else @schema.element(name)
        end
      end
    end
  end
end
