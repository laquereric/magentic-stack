# frozen_string_literal: true

require "date"

require_relative "derivation"
require_relative "types"
require_relative "unspecified"

module Vv
  module Linkml
    # One validation result.
    #
    # `severity` comes from 05validation.md's "Types of checks" table, which
    # assigns each check ERROR, WARNING or INFERENCE. INFERENCE is not a failure:
    # "the validation procedure MAY fill in missing values in the instance. There
    # is only an error if the inferred value is not consistent with the asserted
    # value."
    Problem = Struct.new(:check, :severity, :path, :message, keyword_init: true) do
      def error? = severity == :error
      def warning? = severity == :warning
      def to_s = "#{severity.to_s.upcase} #{check} at #{path}: #{message}"
    end

    # The outcome of validating one instance.
    #
    # READ `conclusive?` BEFORE `valid?`.
    #
    # `valid?` means no ERROR-severity problem was found by the checks that ran.
    # `conclusive?` means every check in scope actually ran. They come apart
    # whenever a schema uses `rules`, `unique_keys`, `classification_rules`,
    # `equals_expression` or a dynamic enum -- because 05validation.md's sections
    # for those are headings with no content (Unspecified::GAPS[:empty_sections]),
    # so there is nothing to implement and this gem does not pretend otherwise.
    #
    # A `valid? && !conclusive?` result is the dangerous one. It looks like a
    # pass and it is a pass over a subset. `skipped` says which subset.
    class Report
      attr_reader :problems, :skipped, :checks_run

      def initialize(problems:, skipped:, checks_run:)
        @problems = problems.freeze
        @skipped = skipped.freeze
        @checks_run = checks_run.freeze
        freeze
      end

      def errors = @problems.select(&:error?)
      def warnings = @problems.select(&:warning?)
      def inferences = @problems.select { |p| p.severity == :inference }

      # No ERROR from the checks that ran. Not the same as "conforms".
      def valid? = errors.empty?

      # Every check the schema calls for actually ran.
      def conclusive? = @skipped.empty?

      def to_s
        state = valid? ? "valid" : "invalid"
        state += " (inconclusive: #{@skipped.size} unimplementable check#{'s' if @skipped.size != 1})" unless conclusive?
        "#<Vv::Linkml::Report #{state} errors=#{errors.size} warnings=#{warnings.size}>"
      end
      alias inspect to_s
    end

    # 05validation.md, for the checks it actually tabulates.
    #
    # The chapter tables 14 named checks across four groups (core, deprecation,
    # atomic, class) plus the enum check. Those are implemented. Four further
    # sections -- Rules, Uniqueness checks, Classification Rule evaluation,
    # Inference of new values -- are headings with no body, and are reported as
    # `skipped` when a schema needs them.
    #
    # Instances are ordinary Ruby: a Hash for an InstanceOfClass, an Array for a
    # CollectionInstance, a scalar for an AtomicInstance, nil for None. Part 2's
    # functional syntax carries the instantiation type on every node; JSON and
    # YAML do not, so the type comes from the schema, exactly as 06mapping.md
    # says ("Parsing from JSON takes as input: a JSON document, a target
    # ElementName, a SchemaDefinition").
    class Validator
      # 05validation.md, "Types of checks".
      SEVERITIES = {
        "Required" => :error, "Recommended" => :warning, "Singlevalued" => :error,
        "Multivalued" => :error, "Inlined" => :error, "Referenced" => :error,
        "ClassRange" => :error, "Datatype" => :error, "NodeKind" => :error,
        "MinimumValue" => :error, "MaximumValue" => :error, "Pattern" => :error,
        "EqualsExpression" => :inference, "StringSerialization" => :inference,
        "TypeDesignator" => :inference,
        # Named in the check tables but absent from the "Types of checks" table.
        "UniqueKey" => :error, "ApplicableSlot" => :error, "Abstract" => :error,
        "Mixin" => :error, "Permissible" => :error, "DesignatedType" => :error,
        "DeprecatedSlot" => :warning, "DeprecatedClass" => :warning,
        "DeprecatedEnum" => :warning, "DeprecatedType" => :warning
      }.freeze

      attr_reader :derived

      def initialize(schema_or_derived, resolver: Derivation.default_resolver)
        @derived =
          case schema_or_derived
          when DerivedSchema then schema_or_derived
          else Derivation.new(schema_or_derived).derive(resolver: resolver)
          end
        @schema = @derived.schema
      end

      # Validate(i, m, t): an instance against a target ClassDefinition name.
      def validate(instance, target)
        problems = []
        skipped = []
        checks_run = Set.new

        unless @derived.complete?
          @derived.gaps.each do |gap|
            skipped << "derived schema is incomplete: #{gap}"
          end
        end

        walk_class(instance, target.to_s, "$", problems, skipped, checks_run)

        Report.new(problems: problems, skipped: skipped.uniq, checks_run: checks_run.to_a.sort)
      end

      private

      def derivation = @derivation ||= Derivation.new(@schema)

      def record(problems, checks_run, check, path, message)
        checks_run << check
        problems << Problem.new(check: check, severity: SEVERITIES.fetch(check, :error),
                                path: path, message: message)
      end

      def walk_class(instance, class_name, path, problems, skipped, checks_run)
        cls = @schema.class_def(class_name)
        if cls.nil?
          record(problems, checks_run, "NodeKind", path,
                 "target #{class_name.inspect} is not a ClassDefinition in this schema")
          return
        end

        unless instance.is_a?(Hash)
          record(problems, checks_run, "NodeKind", path,
                 "expected an InstanceOfClass (a mapping) for #{class_name}, " \
                 "got #{instance.class}")
          return
        end

        checks_run << "Abstract" << "Mixin"
        if cls.abstract?
          record(problems, checks_run, "Abstract", path,
                 "#{class_name} is abstract and cannot be instantiated directly")
        end
        if cls.mixin?
          record(problems, checks_run, "Mixin", path,
                 "#{class_name} is a mixin and cannot be instantiated directly")
        end
        if cls.deprecated?
          record(problems, checks_run, "DeprecatedClass", path,
                 "#{class_name} is deprecated: #{cls.deprecation_reason}")
        end

        induced = @derived.slots_for(class_name)
        note_unimplemented(cls, class_name, skipped)

        # ApplicableSlot: every assignment must name a slot of the class.
        checks_run << "ApplicableSlot"
        instance.each_key do |key|
          next if induced.key?(key.to_s)

          record(problems, checks_run, "ApplicableSlot", "#{path}.#{key}",
                 "#{class_name} has no applicable slot #{key.to_s.inspect}; " \
                 "it has #{induced.keys.sort.join(', ')}")
        end

        induced.each do |slot_alias, slot|
          value = instance.key?(slot_alias) ? instance[slot_alias] : instance[slot_alias.to_sym]
          check_slot(value, slot, "#{path}.#{slot_alias}", problems, skipped, checks_run)
        end
      end

      def check_slot(value, slot, path, problems, skipped, checks_run)
        # 02instances.md: "An assignment of a slot to None is equivalent to
        # omitting that assignment." So nil and absent are the same case.
        absent = value.nil? || (value.is_a?(Array) && value.empty?)

        checks_run << "Required" << "Recommended"
        if absent
          if slot.effectively_required?
            reason = if slot.required?
                       "it is required"
                     else
                       "it is the #{slot.identifier? ? 'identifier' : 'key'} slot, " \
                         "and meta.yaml states identifiers and keys are automatically required"
                     end
            record(problems, checks_run, "Required", path, "#{slot.name} is absent and #{reason}")
          elsif slot.recommended?
            record(problems, checks_run, "Recommended", path,
                   "#{slot.name} is absent and is recommended")
          end
          return
        end

        if slot.deprecated?
          record(problems, checks_run, "DeprecatedSlot", path,
                 "#{slot.name} is deprecated: #{slot.deprecation_reason}")
        end

        checks_run << "Singlevalued" << "Multivalued"
        if value.is_a?(Array) && !slot.multivalued?
          record(problems, checks_run, "Singlevalued", path,
                 "#{slot.name} is not multivalued but the value is a collection " \
                 "of #{value.size}")
          return
        end
        if !value.is_a?(Array) && slot.multivalued?
          record(problems, checks_run, "Multivalued", path,
                 "#{slot.name} is multivalued but the value is a single #{value.class}")
        end

        note_unimplemented_slot(slot, skipped)

        members = value.is_a?(Array) ? value : [value]
        check_cardinality(members, slot, path, problems, checks_run) if value.is_a?(Array)
        check_unique(members, slot, path, problems, checks_run) if value.is_a?(Array)

        members.each_with_index do |member, idx|
          member_path = value.is_a?(Array) ? "#{path}[#{idx}]" : path
          check_value(member, slot, member_path, problems, skipped, checks_run)
        end
      end

      def check_value(value, slot, path, problems, skipped, checks_run)
        range = slot.range
        checks_run << "NodeKind"

        case @schema.range_metatype(range)
        when :class then check_class_range(value, slot, range, path, problems, skipped, checks_run)
        when :enum then check_enum(value, slot, range, path, problems, skipped, checks_run)
        when :type, :builtin_type then check_atomic(value, slot, range, path, problems, checks_run)
        else
          record(problems, checks_run, "NodeKind", path,
                 "range #{range.inspect} of #{slot.name} resolves to no class, enum " \
                 "or type in this schema")
        end
      end

      # Core checks, Inlined and Referenced rows. A class range is either a
      # nested object (inlined) or an identifier value (referenced), and the
      # slot's `inlined` decides which is allowed.
      def check_class_range(value, slot, range, path, problems, skipped, checks_run)
        range_class = @schema.class_def(range)
        if range_class.deprecated?
          record(problems, checks_run, "DeprecatedClass", path,
                 "#{range} is deprecated: #{range_class.deprecation_reason}")
        end

        checks_run << "Inlined" << "Referenced"
        if value.is_a?(Hash)
          if slot.assigned?("inlined") && !slot.inlined?
            record(problems, checks_run, "Referenced", path,
                   "#{slot.name} has inlined=false, so its value must be a reference " \
                   "to a #{range} identifier, not a #{range} object")
            return
          end
          walk_class(value, range, path, problems, skipped, checks_run)
        else
          if slot.inlined?
            record(problems, checks_run, "Inlined", path,
                   "#{slot.name} has inlined=true, so its value must be a #{range} " \
                   "object, not the reference #{value.inspect}")
            return
          end
          pk = @derived.primary_key(range)
          if pk.nil?
            record(problems, checks_run, "Inlined", path,
                   "#{slot.name} carries a reference to #{range}, but #{range} has " \
                   "no identifier or key slot, so nothing can reference it. " \
                   "meta.yaml: \"classes without keys or identifiers are necessarily " \
                   "inlined as lists\"")
          end
        end
      end

      def check_enum(value, slot, range, path, problems, skipped, checks_run)
        enum = @schema.enum(range)
        if enum.deprecated?
          record(problems, checks_run, "DeprecatedEnum", path,
                 "#{range} is deprecated: #{enum.deprecation_reason}")
        end

        values, unresolved = derivation.permissible_values(range)
        unless unresolved.empty?
          skipped << "enum #{range}: permissible values are not fully computable " \
                     "(#{unresolved.join('; ')}), so Permissible was not checked"
          return
        end

        checks_run << "Permissible"
        return if values.include?(value.to_s)

        record(problems, checks_run, "Permissible", path,
               "#{value.inspect} is not a permissible value of #{range}: " \
               "#{values.join(', ')}")
      end

      def check_atomic(value, slot, range, path, problems, checks_run)
        type = @schema.resolve_type(range)
        if type.nil?
          record(problems, checks_run, "NodeKind", path,
                 "range #{range.inspect} resolves to no type")
          return
        end
        if type.deprecated?
          record(problems, checks_run, "DeprecatedType", path,
                 "#{range} is deprecated: #{type.deprecation_reason}")
        end

        checks_run << "Datatype"
        uri = absolute_type_uri(range, type)
        unless conforms?(value, uri)
          record(problems, checks_run, "Datatype", path,
                 "#{value.inspect} (#{value.class}) does not conform to " \
                 "#{range} (#{uri})")
        end

        if slot.pattern
          checks_run << "Pattern"
          unless Regexp.new(slot.pattern).match?(value.to_s)
            record(problems, checks_run, "Pattern", path,
                   "#{value.inspect} does not match #{slot.pattern.inspect}")
          end
        end

        check_bounds(value, slot, path, problems, checks_run)
      end

      def check_bounds(value, slot, path, problems, checks_run)
        if slot.minimum_value && value.is_a?(Numeric)
          checks_run << "MinimumValue"
          if value < slot.minimum_value
            record(problems, checks_run, "MinimumValue", path,
                   "#{value} is below minimum_value #{slot.minimum_value}")
          end
        end
        return unless slot.maximum_value && value.is_a?(Numeric)

        checks_run << "MaximumValue"
        return unless value > slot.maximum_value

        record(problems, checks_run, "MaximumValue", path,
               "#{value} is above maximum_value #{slot.maximum_value}")
      end

      def check_cardinality(members, slot, path, problems, checks_run)
        if slot.minimum_cardinality && members.size < slot.minimum_cardinality
          record(problems, checks_run, "Required", path,
                 "#{members.size} values, below minimum_cardinality " \
                 "#{slot.minimum_cardinality}")
        end
        return unless slot.maximum_cardinality && members.size > slot.maximum_cardinality

        record(problems, checks_run, "Singlevalued", path,
               "#{members.size} values, above maximum_cardinality #{slot.maximum_cardinality}")
      end

      # The UniqueKey row of the core checks: "For each ClassDefinition in the
      # list, the primary key value is calculated, and this is assumed to be
      # unique."
      def check_unique(members, slot, path, problems, checks_run)
        objects = members.select { |m| m.is_a?(Hash) }
        keys =
          if objects.empty?
            members if slot["list_elements_unique"] == true
          else
            pk = @derived.primary_key(slot.range)
            objects.map { |o| o[pk.alias_name] } if pk
          end
        return if keys.nil?

        checks_run << "UniqueKey"
        duplicates = keys.compact.tally.select { |_, n| n > 1 }.keys
        return if duplicates.empty?

        record(problems, checks_run, "UniqueKey", path,
               "duplicate values #{duplicates.map(&:inspect).join(', ')}")
      end

      # The prefixes types.yaml itself declares. A type written `uri: xsd:integer`
      # in a schema that never declared `xsd` still means xsd:integer -- and the
      # Datatype check works on the expanded form, so without this fallback a
      # schema that skipped the prefix declaration would silently pass every
      # datatype check instead of failing them.
      WELL_KNOWN_PREFIXES = {
        "xsd" => "http://www.w3.org/2001/XMLSchema#",
        "shex" => "http://www.w3.org/ns/shex#",
        "linkml" => "https://w3id.org/linkml/"
      }.freeze

      def absolute_type_uri(range, type)
        builtin = Types[range]
        return builtin.uri if builtin && (type.uri.nil? || type.uri == builtin.curie)
        return type.uri if type.uri.nil? || type.uri.include?("://")

        @schema.expanded_prefixes.expand(type.uri) ||
          Curie::Prefixes.new(WELL_KNOWN_PREFIXES).expand(type.uri) ||
          type.uri
      end

      # 05validation.md, "Validation of TypeDefinitions". The chapter names five
      # families; anything outside them is accepted, because the chapter says
      # nothing about them and inventing a rule would be inventing a constraint.
      def conforms?(value, uri)
        case uri
        when "http://www.w3.org/2001/XMLSchema#integer"
          value.is_a?(Integer)
        when "http://www.w3.org/2001/XMLSchema#float",
             "http://www.w3.org/2001/XMLSchema#double",
             "http://www.w3.org/2001/XMLSchema#decimal"
          # "for xsd floats, doubles, and decimals, AtomicValue must be a
          # decimal". An integer literal is a decimal value, so Numeric is the
          # whole test -- narrowing it to Float would reject `1` for a float slot.
          value.is_a?(Numeric)
        when "http://www.w3.org/2001/XMLSchema#boolean"
          value == true || value == false
        when "http://www.w3.org/2001/XMLSchema#date"
          iso?(value, Date)
        when "http://www.w3.org/2001/XMLSchema#dateTime"
          iso?(value, DateTime)
        when "http://www.w3.org/2001/XMLSchema#time"
          value.is_a?(String) && value.match?(/\A\d{2}:\d{2}(:\d{2}(\.\d+)?)?([+-]\d{2}:\d{2}|Z)?\z/)
        when "http://www.w3.org/2001/XMLSchema#anyURI",
             "http://www.w3.org/2001/XMLSchema#string",
             "http://www.w3.org/ns/shex#iri",
             "http://www.w3.org/ns/shex#nonLiteral"
          value.is_a?(String)
        else
          true
        end
      end

      def iso?(value, klass)
        return true if value.is_a?(klass)
        return false unless value.is_a?(String)

        klass.iso8601(value)
        true
      rescue ArgumentError, TypeError
        false
      end

      # The four sections of 05validation.md that have headings and no bodies.
      # A schema that leans on them gets an inconclusive report rather than a
      # quiet pass.
      def note_unimplemented(cls, class_name, skipped)
        unless Array(cls.rules).empty?
          skipped << "class #{class_name} declares #{Array(cls.rules).size} rule(s); " \
                     "05validation.md's \"Rules\" section is a heading with no content " \
                     "(Unspecified::GAPS[:empty_sections])"
        end
        unless cls.unique_keys.empty?
          skipped << "class #{class_name} declares unique_keys; 05validation.md's " \
                     "\"Uniqueness checks\" section is a heading with no content"
        end
        return if Array(cls["classification_rules"]).empty?

        skipped << "class #{class_name} declares classification_rules; " \
                   "05validation.md's \"Classification Rule evaluation\" section is a " \
                   "heading with no content"
      end

      def note_unimplemented_slot(slot, skipped)
        if slot["equals_expression"]
          skipped << "slot #{slot.owner}.#{slot.name} has equals_expression; the " \
                     "EqualsExpression check is INFERENCE severity and " \
                     "05validation.md's \"Inference of new values\" section is empty"
        end
        if slot["string_serialization"]
          skipped << "slot #{slot.owner}.#{slot.name} has string_serialization; " \
                     "the StringSerialization check needs the same missing section"
        end
        if slot.designates_type?
          skipped << "slot #{slot.owner}.#{slot.name} designates_type; the " \
                     "DesignatedType check requires the deepening procedure of " \
                     "06mapping.md, which this gem does not implement"
        end
        return unless slot.boolean_expressions?

        skipped << "slot #{slot.owner}.#{slot.name} uses any_of/all_of/none_of/" \
                   "exactly_one_of; 05validation.md gives their truth conditions but " \
                   "no procedure for evaluating a slot expression against a value"
      end
    end
  end
end
