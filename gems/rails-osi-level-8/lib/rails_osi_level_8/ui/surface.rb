# frozen_string_literal: true

module RailsOsiLevel8
  module Ui
    # Slot on a Page, not a parallel tree. Writes compile from an
    # information model (F4); BACK admits the compile, not a draft tree.
    module Surface
      TASK_KINDS = %w[
        task.form task.confirm task.error task.empty task.approval task.preview task.date
        task.table task.status task.choice task.progress_steps task.citation
      ].freeze
      GRAPH_KEYS = %w[graph_iri spec_iri graphIri specIri].freeze
      PUT_KEYS = %w[
        taskKind informationModel informationModelCid fields title
        stepKind document as pageCid reviewedDigest blobDigest catalogVersion
      ].freeze + GRAPH_KEYS
      GET_KEYS = %w[digest aciaCid as].freeze

      module_function

      def reset!
        @docs = {}
        Action.reset! if defined?(Action)
        Blob.reset! if defined?(Blob)
      end

      def store_get(cid)
        store[cid.to_s]
      end

      def put(params)
        params = Profile9::Request.closed!(params || {}, PUT_KEYS)
        task_kind = params["taskKind"].to_s
        unless TASK_KINDS.include?(task_kind)
          raise KnownRefusal.new(
            "kind_not_in_catalog",
            { "taskKind" => task_kind, "allowed" => TASK_KINDS }
          )
        end

        minted = GRAPH_KEYS.select { |k| Profile9::Request.present?(params[k]) }
        if minted.any?
          raise KnownRefusal.new(
            "graph_iri_refused",
            { "keys" => minted, "message" => "canvas does not mint graph IRIs; digest is the name" }
          )
        end

        if task_kind == "task.form" && model_fields(params).empty?
          raise KnownRefusal.new(
            "information_model_required",
            { "taskKind" => task_kind }
          )
        end

        if task_kind == "task.preview"
          digest = params["blobDigest"].to_s
          unless digest.match?(/\Asha256:[0-9a-f]{64}\z/)
            raise KnownRefusal.new(
              "blob_digest_required",
              { "blobDigest" => digest }
            )
          end
        end

        if params["document"].is_a?(Hash)
          gate_document!(params["document"])
        end

        catalog_version = params["catalogVersion"].to_s
        catalog_version = (task_kind == "task.date" ? Profile9::Compile::GHIS_20 : Profile9::Compile::CATALOG_VERSION) if catalog_version.empty?

        compiled = Profile9::Compile.call(
          fields: model_fields(params),
          step_kind: step_kind_for(task_kind, params),
          title: params["title"].to_s.empty? ? task_kind : params["title"],
          catalog_version: catalog_version,
          reviewed_digest: params["reviewedDigest"],
          blob_digest: params["blobDigest"]
        )
        unless compiled["ok"]
          raise KnownRefusal.new(compiled["reason"], compiled["because"] || {})
        end

        if params["document"].is_a?(Hash)
          given = Profile9::Acia.validate(params["document"])
          unless given.conforms? && given.digest == compiled["digest"]
            raise KnownRefusal.new(
              "compile_mismatch",
              { "expected" => compiled["digest"], "got" => given.digest }
            )
          end
        end

        rec = {
          "cid" => compiled["aciaCid"],
          "digest" => compiled["digest"],
          "taskKind" => task_kind,
          "informationModelCid" => params["informationModelCid"],
          "document" => compiled["document"],
          "catalogVersion" => compiled["catalogVersion"],
          "pageCid" => params["pageCid"],
          "blobDigest" => params["blobDigest"]
        }
        store[rec["cid"]] = rec
        rec.merge("ok" => true)
      end

      def get(params)
        params = Profile9::Request.closed!(params || {}, GET_KEYS)
        cid = (params["aciaCid"] || params["digest"]).to_s
        cid = "cid:acia:#{cid.delete_prefix('sha256:')}" if cid.start_with?("sha256:")
        rec = store[cid]
        unless rec
          raise KnownRefusal.new(
            Profile9::Vocabulary::REFUSAL_CODES[:lineage_unresolved],
            { "resource" => "surface", "cid" => cid }
          )
        end

        as = params["as"].to_s
        as = "acia" if as.empty?
        case as
        when "acia"
          rec
        when "html"
          rendered = Profile9::Renderer.render(
            "aciaDocument" => rec["document"],
            "tokenSet" => Profile9::Renderer.default_token_set
          )
          rec.merge("html" => rendered["html"], "receipt" => rendered["receipt"])
        when "a2ui"
          rec.merge("a2ui" => A2ui.emit(rec["document"], surface_id: rec["cid"]))
        when "adaptive-cards"
          rec.merge("adaptiveCards" => AdaptiveCards.emit(rec["document"], surface_id: rec["cid"]))
        when "block-kit"
          rec.merge("blockKit" => BlockKit.emit(rec["document"], surface_id: rec["cid"]))
        else
          raise KnownRefusal.new(
            "as_not_supported",
            { "as" => as, "allowed" => %w[acia html a2ui adaptive-cards block-kit] }
          )
        end
      end

      def store
        @docs ||= {}
      end
      private_class_method :store

      def model_fields(params)
        if params["fields"].is_a?(Array)
          params["fields"]
        elsif params["informationModel"].is_a?(Hash)
          Array(params["informationModel"]["fields"])
        else
          []
        end
      end
      private_class_method :model_fields

      def step_kind_for(task_kind, params)
        explicit = params["stepKind"].to_s
        return explicit unless explicit.empty?

        case task_kind
        when "task.form" then "collect"
        when "task.confirm" then "confirm"
        when "task.error" then "error"
        when "task.empty" then "empty"
        when "task.approval" then "approval"
        when "task.preview" then "preview"
        when "task.date" then "date"
        when "task.table" then "table"
        when "task.status" then "status"
        when "task.choice" then "choice"
        when "task.progress_steps" then "progress_steps"
        when "task.citation" then "citation"
        else "collect"
        end
      end
      private_class_method :step_kind_for

      def gate_document!(doc)
        validation = Profile9::Acia.validate(doc)
        return if validation.conforms?

        forbidden = Array((validation.because || {})["forbidden_props"])
        if forbidden.any? { |k| Profile9::Acia::FORBIDDEN_PROP_KEYS.include?(k.to_s) }
          raise KnownRefusal.new(
            "html_forbidden",
            (validation.because || {}).merge("forbidden_props" => forbidden)
          )
        end
        raise KnownRefusal.new(validation.reason, validation.because || {})
      end
      private_class_method :gate_document!
    end
  end
end
