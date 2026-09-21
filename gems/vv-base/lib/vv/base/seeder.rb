# frozen_string_literal: true

require "pathname"
require "yaml"

module Vv
  module Base
    # ADR 0074 decision 4. The declarative loader for canonical homes.
    #
    # Modelled on Vv::PerSite::Okf::Seeder: read YAML from a seed root, apply
    # idempotently by natural key, parent before child, and return a result
    # hash rather than raising. Reused rather than invented, which is what kept
    # the actor work small.
    #
    # Two rules distinguish this from the hand-written seeding it replaces.
    #
    # REFUSE, DO NOT SKIP. An unknown key is an error, not something to ignore.
    # A seed that names `titel:` should fail loudly; silently dropping it is how
    # a seed and a schema drift apart while both look healthy.
    #
    # NEVER DERIVE A KEY. journey_key and flow_key must be stated. The 2026-09-21
    # migration derives them from title ONCE, to backfill rows written before
    # keys existed. A loader that did the same would put implicit identity back
    # at the centre of a mechanism that exists to remove it -- two seeds with the
    # same title would silently become one row, which is the defect in ADR 0074's
    # Context wearing a different hat.
    #
    # bundle_key comes from the ARGUMENT, not the file. Decision 3: bundle_key is
    # a value the seed carries, never a registry -- and the caller is what knows
    # which bundle it is seeding. A document that names a different one is
    # refused rather than quietly re-stamped.
    module Seeder
      module_function

      TOP_KEYS      = %w[bundle_key actors information_models journeys].freeze
      ACTOR_KEYS    = %w[role_key name capabilities_json ledger_placement].freeze
      MODEL_KEYS    = %w[key title subject_type ledger_placement fields].freeze
      FIELD_KEYS    = %w[ordinal name datatype required cardinality enum_key meaning_concept_cid].freeze
      JOURNEY_KEYS  = %w[journey_key title goal scenario status primary_actor_role_key ledger_placement flows].freeze
      FLOW_KEYS     = %w[flow_key title task_goal status ledger_placement steps].freeze
      STEP_KEYS     = %w[ordinal step_key title kind information_model route_key ledger_placement].freeze

      class Refusal < StandardError
        attr_reader :reason

        def initialize(reason, because)
          @reason = reason
          super(because)
        end
      end

      # seed_root: a directory of .yml documents, or a single .yml file.
      # bundle_key: the bundle these rows belong to. Required; there is no default.
      def load!(seed_root:, bundle_key:)
        return refusal(:no_bundle_key, "bundle_key is required; the loader is told the bundle, it does not guess") if to_s_or_nil(bundle_key).nil?

        docs = read_docs(seed_root)
        return refusal(:seed_missing, seed_root.to_s) if docs.nil?
        return refusal(:empty, seed_root.to_s) if docs.empty?

        counts = Hash.new(0)
        # requires_new, so this is a savepoint rather than a no-op when the
        # caller already has a transaction open -- a host's db:seed, or a spec
        # that wraps each example. Without it a refusal half way through leaves
        # the rows written before it, which is a partial seed presented as a
        # refused one.
        ActiveRecord::Base.transaction(requires_new: true) do
          docs.each { |doc| apply_doc(doc, bundle_key.to_s, counts) }
        end
        { ok: true, bundle_key: bundle_key.to_s }.merge(counts)
      rescue Refusal => e
        { ok: false, reason: e.reason, because: e.message }
      rescue StandardError => e
        { ok: false, reason: :load_failed, because: "#{e.class}: #{e.message}" }
      end

      # ---------- reading ----------

      def read_docs(seed_root)
        root = Pathname.new(seed_root.to_s).expand_path
        return [load_yaml(root)].compact if root.file?
        return nil unless root.directory?

        paths = manifest_paths(root) || root.glob("**/*.yml").reject { |p| p.basename.to_s.start_with?("_") }.sort
        paths.map { |p| load_yaml(p) }.compact
      end

      def manifest_paths(root)
        manifest = root.join("_manifest.yml")
        return nil unless manifest.file?

        files = Array((load_yaml(manifest) || {})["files"])
        return nil if files.empty?

        files.map { |rel| root.join(rel) }
      end

      def load_yaml(path)
        return nil unless path.file?
        return nil if path.basename.to_s == "_manifest.yml"

        YAML.safe_load(path.read, permitted_classes: [Date, Time], aliases: true)
      end

      # ---------- applying ----------

      def apply_doc(doc, bundle_key, counts)
        refuse(:not_a_mapping, "a seed document must be a mapping, got #{doc.class}") unless doc.is_a?(Hash)
        check_keys!(doc, TOP_KEYS, "document")

        stated = to_s_or_nil(doc["bundle_key"])
        if stated && stated != bundle_key
          refuse(:bundle_key_mismatch, "document says bundle_key=#{stated.inspect} but the loader was called with #{bundle_key.inspect}")
        end

        # Parent before child, and across kinds too: an actor must exist before a
        # journey names it, a model before a collect step points at it.
        Array(doc["actors"]).each { |a| counts[:actors] += upsert_actor(a, bundle_key) }
        Array(doc["information_models"]).each { |m| upsert_model(m, bundle_key, counts) }
        Array(doc["journeys"]).each { |j| upsert_journey(j, bundle_key, counts) }
      end

      def upsert_actor(attrs, bundle_key)
        check_keys!(attrs, ACTOR_KEYS, "actor")
        role_key = required!(attrs, "role_key", "actor")
        row = Actor.find_or_initialize_by(bundle_key: bundle_key, role_key: role_key)
        row.name = attrs["name"] if attrs.key?("name")
        row.name ||= role_key
        row.capabilities_json = attrs["capabilities_json"] if attrs.key?("capabilities_json")
        row.ledger_placement = attrs["ledger_placement"] || row.ledger_placement || "canonical"
        row.save!
        1
      end

      def upsert_model(attrs, bundle_key, counts)
        check_keys!(attrs, MODEL_KEYS, "information model")
        key = required!(attrs, "key", "information model")
        row = InformationModel.find_or_initialize_by(bundle_key: bundle_key, key: key)
        row.title = attrs["title"] || row.title || key
        row.subject_type = attrs["subject_type"] if attrs.key?("subject_type")
        row.ledger_placement = attrs["ledger_placement"] || row.ledger_placement || "canonical"
        row.save!
        counts[:information_models] += 1

        Array(attrs["fields"]).each do |f|
          check_keys!(f, FIELD_KEYS, "information field")
          name = required!(f, "name", "information field")
          field = row.fields.find_or_initialize_by(name: name)
          field.datatype = f["datatype"] if f.key?("datatype")
          field.ordinal = f["ordinal"] if f.key?("ordinal")
          field.required = f["required"] unless f["required"].nil?
          field.cardinality = f["cardinality"] if f.key?("cardinality")
          field.enum_key = f["enum_key"] if f.key?("enum_key")
          field.meaning_concept_cid = f["meaning_concept_cid"] if f.key?("meaning_concept_cid")
          field.save!
          counts[:information_fields] += 1
        end
      end

      def upsert_journey(attrs, bundle_key, counts)
        check_keys!(attrs, JOURNEY_KEYS, "journey")
        journey_key = required!(attrs, "journey_key", "journey")
        row = Journey.find_or_initialize_by(bundle_key: bundle_key, journey_key: journey_key)
        row.title = attrs["title"] || row.title || journey_key
        row.goal = attrs["goal"] if attrs.key?("goal")
        row.scenario = attrs["scenario"] if attrs.key?("scenario")
        row.status = attrs["status"] || row.status || "draft"
        row.ledger_placement = attrs["ledger_placement"] || row.ledger_placement || "canonical"

        if (role = to_s_or_nil(attrs["primary_actor_role_key"]))
          actor = Actor.find_by(bundle_key: bundle_key, role_key: role)
          refuse(:unresolved_actor, "journey #{journey_key.inspect} names primary_actor_role_key #{role.inspect}, which is not seeded in bundle #{bundle_key.inspect}") if actor.nil?
          row.primary_actor_id = actor.id
        end
        row.save!
        counts[:journeys] += 1

        Array(attrs["flows"]).each { |f| upsert_flow(f, row, bundle_key, counts) }
      end

      def upsert_flow(attrs, journey, bundle_key, counts)
        check_keys!(attrs, FLOW_KEYS, "flow")
        flow_key = required!(attrs, "flow_key", "flow")
        row = journey.flows.find_or_initialize_by(flow_key: flow_key)
        row.title = attrs["title"] || row.title || flow_key
        row.task_goal = attrs["task_goal"] if attrs.key?("task_goal")
        row.status = attrs["status"] || row.status || "draft"
        row.ledger_placement = attrs["ledger_placement"] || row.ledger_placement || "canonical"

        # Steps before the flow is saved as active: Flow validates that an active
        # flow has steps, so saving it active first would refuse its own seed.
        wanted_status = row.status
        row.status = "draft"
        row.save!

        Array(attrs["steps"]).each { |s| upsert_step(s, row, bundle_key, counts) }
        counts[:flows] += 1

        return if wanted_status == "draft"

        row.status = wanted_status
        row.save!
      end

      def upsert_step(attrs, flow, bundle_key, counts)
        check_keys!(attrs, STEP_KEYS, "flow step")
        step_key = required!(attrs, "step_key", "flow step")
        row = flow.steps.find_or_initialize_by(step_key: step_key)
        row.title = attrs["title"] || row.title || step_key
        row.kind = attrs["kind"] if attrs.key?("kind")
        row.ordinal = attrs["ordinal"] if attrs.key?("ordinal")
        row.route_key = attrs["route_key"] if attrs.key?("route_key")
        row.ledger_placement = attrs["ledger_placement"] || row.ledger_placement || "canonical"

        if (model_key = to_s_or_nil(attrs["information_model"]))
          model = InformationModel.find_by(bundle_key: bundle_key, key: model_key)
          refuse(:unresolved_information_model, "step #{step_key.inspect} names information_model #{model_key.inspect}, which is not seeded in bundle #{bundle_key.inspect}") if model.nil?
          row.information_model_id = model.id
        end
        row.save!
        counts[:flow_steps] += 1
      end

      # ---------- refusals ----------

      def check_keys!(attrs, allowed, what)
        refuse(:not_a_mapping, "a #{what} must be a mapping, got #{attrs.class}") unless attrs.is_a?(Hash)
        unknown = attrs.keys.map(&:to_s) - allowed
        return if unknown.empty?

        refuse(:unknown_key, "#{what} has unknown key(s) #{unknown.sort.inspect}; allowed: #{allowed.inspect}")
      end

      def required!(attrs, key, what)
        value = to_s_or_nil(attrs[key])
        refuse(:missing_key, "#{what} is missing #{key.inspect}, which is its natural key and is never derived") if value.nil?
        value
      end

      def refuse(reason, because)
        raise Refusal.new(reason, because)
      end

      def refusal(reason, because)
        { ok: false, reason: reason, because: because }
      end

      def to_s_or_nil(value)
        s = value.to_s.strip
        s.empty? ? nil : s
      end
    end
  end
end
