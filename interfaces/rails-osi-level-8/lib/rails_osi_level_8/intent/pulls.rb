# frozen_string_literal: true

module RailsOsiLevel8
  module Intent
    # P10.M4 — Context PULLs. private_local never returned nor existence-disclosed.
    module Pulls
      module_function

      def mission_get(params)
        params = stringify(params)
        refuse_private_scope!(params)
        rec = find_canonical(::Mission, params)
        raise KnownRefusal.new("not_found", { "resource" => "mission" }) unless rec

        Projection.for(rec)
      end

      def vision_get(params)
        params = stringify(params)
        refuse_private_scope!(params)
        rec = find_canonical(::Vision, params)
        raise KnownRefusal.new("not_found", { "resource" => "vision" }) unless rec

        Projection.for(rec)
      end

      def persona_list(params)
        params = stringify(params)
        refuse_private_scope!(params)
        rel = ::Persona.all
        rel = rel.where(status: "ratified") unless params["includeDraft"] == true
        page(rel.order(:id), params).map { |r| Projection.for(r) }
      end

      def stakeholder_list(params)
        params = stringify(params)
        refuse_private_scope!(params)
        rel = Intent::Stakeholder.cross_boundary
        rel = rel.where(stakeholder_kind: params["stakeholderKind"]) if present?(params["stakeholderKind"])
        page(rel.order(:created_at), params).map { |r| serialize_intent_row(r, "intent:Stakeholder") }
      end

      def value_proposition_list(params)
        params = stringify(params)
        refuse_private_scope!(params)
        rel = Intent::ValueProposition.cross_boundary
        page(rel.order(:created_at), params).map { |r| serialize_intent_row(r, "intent:ValueProposition") }
      end

      def segment_list(params)
        params = stringify(params)
        refuse_private_scope!(params)
        rel = Intent::MarketSegment.cross_boundary
        rel = rel.where(kind: params["kind"]) if present?(params["kind"])
        page(rel.order(:created_at), params).map { |r| serialize_intent_row(r, "intent:MarketSegment") }
      end

      def goal_list(params)
        params = stringify(params)
        refuse_private_scope!(params)
        rel = Intent::Goal.cross_boundary
        rel = rel.where(kind: params["kind"]) if present?(params["kind"])
        page(rel.order(:created_at), params).map { |r| serialize_intent_row(r, "intent:Goal") }
      end

      def trace_for_effect(params)
        params = stringify(params)
        refuse_private_scope!(params)
        effect_cid = params["effectCid"].to_s
        raise KnownRefusal.new("missing_params", { "missing" => "effectCid" }) if effect_cid.empty?

        traces = GraphStore.find_by(type: "intent:IntentTrace", effect_cid: effect_cid, ledger: "cross_boundary")
        return { "found" => false, "effectCid" => effect_cid } if traces.empty?

        t = traces.first
        {
          "found" => true,
          "trace" => t,
          "grounding" => GraphStore.get(t["groundingCid"]),
          "missionCid" => t["missionCid"],
          "personaCid" => t["personaCid"],
          "goalCid" => t["goalCid"],
          "valuePropositionCid" => t["valuePropositionCid"]
        }
      end

      def refuse_private_scope!(params)
        scope = Array(params["ledgerScope"] || params["ledger_scope"])
        return unless scope.map(&:to_s).include?("private_local")

        raise KnownRefusal.new(
          "ledger_scope_forbidden",
          { "reason" => "private_local_never_disclosed", "profile_id" => "osi-level-8/profile-10" }
        )
      end
      private_class_method :refuse_private_scope!

      def find_canonical(model, params)
        return model.find_by(id: params["id"]) if present?(params["id"])
        if present?(params["cid"])
          model.find_each { |r| return r if Projection.for(r)["cid"] == params["cid"] }
          return nil
        end
        return model.where(status: %w[ratified active]).order(:id).first if params["active"] == true || params["active"] == "true"
        return model.find_by(title: params["slug"]) if present?(params["slug"]) && model.column_names.include?("title")
        return model.find_by(name: params["slug"]) if present?(params["slug"]) && model.column_names.include?("name")

        nil
      end
      private_class_method :find_canonical

      def page(rel, params)
        limit = [[(params.dig("page", "limit") || params["limit"] || 25).to_i, 1].max, 100].min
        rel.limit(limit)
      end
      private_class_method :page

      def serialize_intent_row(r, type)
        {
          "@id" => r.cid,
          "@type" => type,
          "cid" => r.cid,
          "profileId" => r.profile_id,
          "ledgerPlacement" => r.ledger_placement,
          "state" => r.state,
          "digest" => "sha256:#{r.payload_digest}",
          "attributes" => r.attributes.except(
            "id", "cid", "profile_id", "ledger_placement", "state", "payload_digest",
            "provenance_actor_cid", "provenance_source_cid", "created_at", "updated_at"
          )
        }
      end
      private_class_method :serialize_intent_row

      def present?(v)
        !(v.nil? || (v.respond_to?(:empty?) && v.empty?))
      end
      private_class_method :present?

      def stringify(obj)
        GraphStore.stringify(obj)
      end
      private_class_method :stringify
    end
  end
end
