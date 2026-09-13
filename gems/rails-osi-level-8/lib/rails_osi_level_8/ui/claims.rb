# frozen_string_literal: true

module RailsOsiLevel8
  module Ui
    # In-process stand-in for a claimed BPMN HumanReview job.
    # Mind-pod replaces Action.claim_gate with a check against
    # Vv::Sdlc::Engine rows. This gem does not depend on vv-sdlc.
    module Claims
      module_function

      def reset!
        @rows = {}
      end

      def register!(job_id:, actor_id:, element_id: "HumanReview")
        raise ArgumentError, "job_id required" if job_id.nil?
        raise ArgumentError, "actor_id required" if actor_id.nil?

        @rows ||= {}
        @rows[job_id.to_s] = {
          "jobId" => job_id.to_s,
          "actorId" => actor_id.to_s,
          "elementId" => element_id.to_s,
          "state" => "claimed"
        }
      end

      def verify(params)
        params = params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
        job_id = (params["jobId"] || params["job_id"]).to_s
        actor_id = (params["actorCid"] || params["actorId"] || params["actor_id"]).to_s
        if job_id.empty? || actor_id.empty?
          return {
            "ok" => false,
            "reason" => "claim_required",
            "because" => { "missing" => %w[jobId actorCid].reject { |k|
              k == "jobId" ? job_id.empty? : actor_id.empty?
            } }
          }
        end

        row = (@rows || {})[job_id]
        unless row && row["state"] == "claimed" && row["actorId"] == actor_id
          return {
            "ok" => false,
            "reason" => "claim_required",
            "because" => {
              "jobId" => job_id,
              "actorCid" => actor_id,
              "message" => "HumanReview must be claimed by this Actor"
            }
          }
        end
        { "ok" => true, "job" => row }
      end
    end
  end
end
