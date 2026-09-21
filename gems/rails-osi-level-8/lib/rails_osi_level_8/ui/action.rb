# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  module Ui
    # Human activated a component. Journalled. Never a machine Effect:
    # the agent does not close Effect by calling this.
    #
    # task.approval accept/reject requires a claimed HumanReview
    # (S3). Default gate is Ui::Claims; BACK may replace claim_gate
    # with a check against vv-sdlc jobs.
    module Action
      KEYS = %w[
        surfaceCid aciaCid action actorCid actorId jobId job_id
        payload componentId machineEffectCid
      ].freeze
      ALLOWED = {
        "task.form" => %w[submit],
        "task.confirm" => %w[accept reject],
        "task.approval" => %w[accept reject],
        "task.error" => %w[acknowledge],
        "task.empty" => %w[dismiss]
      }.freeze

      module_function

      def reset!
        @log = []
        Claims.reset!
      end

      def claim_gate=(callable)
        @claim_gate = callable
      end

      def claim_gate
        @claim_gate || ->(p) { Claims.verify(p) }
      end

      def call(params)
        params = Profile9::Request.closed!(params || {}, KEYS)
        if params.key?("machineEffectCid")
          raise KnownRefusal.new(
            "agent_closes_effect",
            { "message" => "ui.action does not close a machine Effect" }
          )
        end

        cid = (params["surfaceCid"] || params["aciaCid"]).to_s
        rec = Surface.store_get(cid)
        unless rec
          raise KnownRefusal.new(
            Profile9::Vocabulary::REFUSAL_CODES[:lineage_unresolved],
            { "resource" => "surface", "cid" => cid }
          )
        end

        action = params["action"].to_s
        allowed = ALLOWED[rec["taskKind"]] || []
        unless allowed.include?(action)
          raise KnownRefusal.new(
            "kind_not_in_catalog",
            { "action" => action, "taskKind" => rec["taskKind"], "allowed" => allowed }
          )
        end

        # AN ACTION RECORDS WHO TOOK IT. G13's canonical line names this surface
        # directly -- "actorCid on artifact put and on ui.action" -- and this
        # recorded nil when no actor was supplied. That is honester than the
        # constant profile9 substituted (a nil actor is at least visible), but
        # it still writes an action into the ledger that nobody is answerable
        # for. Normalise first, then require: actorId is the older spelling and
        # is still live in claims.rb and the mind-pod initializer, so it is
        # accepted rather than broken -- but one of the two must be there.
        params = params.merge(
          "actorCid" => (params["actorCid"] || params["actorId"]).to_s
        )
        actor_cid = Profile9::Request.require_cid!(params, "actorCid")
        job_proof = nil
        if rec["taskKind"] == "task.approval" && %w[accept reject].include?(action)
          proof = claim_gate.call(params.merge("actorCid" => actor_cid))
          proof = stringify(proof)
          unless proof["ok"]
            raise KnownRefusal.new(
              proof["reason"] || "claim_required",
              proof["because"] || { "taskKind" => "task.approval" }
            )
          end
          job_proof = proof["job"]
        end

        entry = {
          "cid" => next_cid(cid, action),
          "@type" => "ui:Action",
          "surfaceCid" => rec["cid"],
          "taskKind" => rec["taskKind"],
          "action" => action,
          "actorCid" => actor_cid,
          "job" => job_proof,
          "componentId" => params["componentId"],
          "payload" => params["payload"],
          "ledgerPlacement" => "canonical",
          # R2: a clock, not a ledger. The array still dies with BACK.
          "at" => stamp_at
        }
        log << entry
        entry.merge("ok" => true)
      end

      def journal
        log.dup
      end

      def log
        @log ||= []
      end
      private_class_method :log

      def next_cid(surface_cid, action)
        n = log.size + 1
        digest = Digest::SHA256.hexdigest("#{surface_cid}:#{action}:#{n}")
        "cid:ui-action:#{digest[0, 24]}"
      end
      private_class_method :next_cid

      def stamp_at
        clock = RailsOsiLevel8.config.clock.call
        clock.respond_to?(:utc) ? clock.utc.iso8601(6) : clock.to_s
      end
      private_class_method :stamp_at

      def stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array then obj.map { |v| stringify(v) }
        else obj
        end
      end
      private_class_method :stringify
    end
  end
end
