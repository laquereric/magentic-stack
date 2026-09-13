# frozen_string_literal: true

# Level 8 engine wiring (Milestone 0). No new route — /_cpcp remains the only seam.
RailsOsiLevel8.configure do |config|
  config.role = ENV.fetch("ROLE", "back")
  config.cpcp_path = "/_cpcp/rpc"
  # ADR 0044: resolution is ProfileCatalog's per-shape map, not shape_root.
  config.profile_catalog = RailsOsiLevel8::ProfileCatalog.default
  config.public_ledgers = %w[canonical sync_intent].freeze
  config.private_ledger = "private_local"
  config.clock = -> { Time.current }
  config.base_iri = ENV.fetch("OSI8_BASE_IRI", ENV.fetch("BASE_IRI", "https://mind-pod.local"))
end

Rails.application.config.to_prepare do
  # Register the decorator only in the HTTP writer. FRONT receives no AR repository.
  RailsOsiLevel8::CpcpAdapter.install!(RailsCpcp) if ENV.fetch("ROLE", "back") == "back"

  # S3: task.approval accept requires a claimed HumanReview. The gem's
  # default gate is an in-process registry; BACK checks vv-sdlc jobs.
  RailsOsiLevel8::Ui::Action.claim_gate = lambda { |params|
    begin
      p = params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
      job_id = p["jobId"] || p["job_id"]
      actor_id = p["actorCid"] || p["actorId"] || p["actor_id"]
      if job_id.nil? || actor_id.to_s.empty?
        next { "ok" => false, "reason" => "claim_required",
               "because" => { "missing" => "jobId/actorCid" } }
      end
      unless defined?(::Vv::BpmnBbo::Run::Job)
        next { "ok" => false, "reason" => "claim_required",
               "because" => { "message" => "bpmn jobs not loaded" } }
      end
      job = ::Vv::BpmnBbo::Run::Job.find_by(id: job_id)
      unless job && job.kind == "user" && job.state == "claimed" &&
             job.claimed_by.to_s == "actor:#{actor_id}"
        next { "ok" => false, "reason" => "claim_required",
               "because" => { "jobId" => job_id, "actorCid" => actor_id,
                              "message" => "HumanReview must be claimed by this Actor" } }
      end
      { "ok" => true,
        "job" => { "jobId" => job.id.to_s, "actorId" => actor_id.to_s,
                   "elementId" => job.flow_node.element_id, "state" => job.state } }
    rescue StandardError => e
      { "ok" => false, "reason" => "claim_required",
        "because" => { "message" => e.message.to_s[0, 200] } }
    end
  }
end
