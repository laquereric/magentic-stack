# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Sdlc
    # Token engine over vv-bpmn-bbo run rows. Only the current job can be
    # completed, so HumanReview cannot be skipped. User tasks require a
    # claimed Vv::Base::Actor. Service tasks (including AgentTests) do not
    # gate End by themselves.
    class Engine
      PACKAGE_KEY = Seed::PACKAGE_KEY

      def self.handles?(params)
        params.to_h["definition_key"].to_s == PACKAGE_KEY
      end

      def self.seed = Seed.call

      def self.start(params) = new.start(params)
      def self.claim(params) = new.claim(params)
      def self.complete(params) = new.complete(params)
      def self.jobs(params) = new.jobs(params)

      def start(params)
        seeded = Seed.call
        return seeded unless seeded[:ok]

        key = params["definition_key"].to_s
        return refuse(:definition_key_required, "definition_key is required") if key.empty?
        return refuse(:not_sdlc, "vv-sdlc only starts definition_key=#{PACKAGE_KEY}") unless key == PACKAGE_KEY

        pkg = Vv::BpmnBbo::Package.find_by(definition_key: key)
        ver = pkg.definition_versions.find_by(is_latest: true)
        proc = ver.processes.find_by(element_id: Seed::PROCESS_ID)
        return refuse(:process_missing, "AgentTask process not seeded") unless proc

        start_node = proc.flow_nodes.find_by(type: "Vv::BpmnBbo::StartEvent")
        return refuse(:start_missing, "no StartEvent") unless start_node

        inst = nil
        ::ActiveRecord::Base.transaction(requires_new: true) do
          inst = Vv::BpmnBbo::Run::ProcessInstance.create!(
            process: proc, state: "running", started_at: Time.now.utc,
            business_key: params["business_key"]
          )
          place!(inst, start_node, outcome: nil)
        end
        ok_instance(inst)
      rescue ::StandardError => e
        refuse(:start_failed, "#{e.class}: #{e.message}")
      end

      def claim(params)
        job, err = find_job(params)
        return err if err
        return refuse(:not_user_task, "only HumanReview (user) jobs are claimed") unless job.kind == "user"
        return refuse(:job_not_open, "job is #{job.state}") unless job.state == "open"

        actor_id = params["actor_id"]
        return refuse(:actor_required, "actor_id is required to claim a review") if actor_id.nil?
        unless defined?(::Vv::Base::Actor) && ::Vv::Base::Actor.exists?(actor_id)
          return refuse(:actor_missing, "Vv::Base::Actor #{actor_id} does not exist")
        end

        job.update!(state: "claimed", claimed_at: Time.now.utc, claimed_by: "actor:#{actor_id}")
        { ok: true, job: job_row(job.reload) }
      rescue ::StandardError => e
        refuse(:claim_failed, "#{e.class}: #{e.message}")
      end

      def complete(params)
        job, err = find_job(params)
        return err if err
        if job.kind == "user"
          return refuse(:job_not_claimed, "HumanReview must be claimed by an Actor first") unless job.state == "claimed"
        else
          return refuse(:job_not_open, "job is #{job.state}") unless %w[open claimed].include?(job.state)
        end

        outcome = params["outcome"].to_s
        outcome = "done" if outcome.empty?

        inst = job.process_instance
        ::ActiveRecord::Base.transaction(requires_new: true) do
          job.update!(state: "completed")
          job.activity_instance.update!(state: "completed", ended_at: Time.now.utc)
          nxt = next_node(job.flow_node, outcome)
          place!(inst, nxt, outcome: outcome)
        end
        ok_instance(inst.reload)
      rescue ::StandardError => e
        refuse(:complete_failed, "#{e.class}: #{e.message}")
      end

      def jobs(params)
        inst_id = params["process_instance_id"]
        rel = Vv::BpmnBbo::Run::Job.where(state: %w[open claimed])
        rel = rel.where(process_instance_id: inst_id) if inst_id
        { ok: true, jobs: rel.order(:id).map { |j| job_row(j) } }
      rescue ::StandardError => e
        refuse(:jobs_failed, "#{e.class}: #{e.message}")
      end

      private

      def place!(inst, node, outcome:)
        if node.nil? || node.is_a?(Vv::BpmnBbo::EndEvent)
          finish!(inst, node)
          return
        end

        ai = Vv::BpmnBbo::Run::ActivityInstance.create!(
          process_instance: inst, flow_node: node, state: "active", started_at: Time.now.utc
        )

        if auto?(node)
          ai.update!(state: "completed", ended_at: Time.now.utc)
          place!(inst, next_node(node, outcome), outcome: outcome)
          return
        end

        kind = node.is_a?(Vv::BpmnBbo::UserTask) ? "user" : "service"
        Vv::BpmnBbo::Run::Job.create!(
          process_instance: inst, activity_instance: ai, flow_node: node,
          kind: kind, state: "open"
        )
      end

      def auto?(node)
        node.is_a?(Vv::BpmnBbo::StartEvent) || node.is_a?(Vv::BpmnBbo::Gateway)
      end

      def next_node(node, outcome)
        flows = node.outgoing.to_a
        return nil if flows.empty?
        return flows.first.target if flows.size == 1

        if outcome.to_s == "reject"
          hit = flows.find { |f| f.condition_expression&.body.to_s.include?("reject") }
          return (hit || node.default_flow || flows.first).target
        end
        (node.default_flow || flows.find { |f| f.condition_expression_id.nil? } || flows.first).target
      end

      def finish!(inst, node)
        if node
          Vv::BpmnBbo::Run::ActivityInstance.create!(
            process_instance: inst, flow_node: node, state: "completed",
            started_at: Time.now.utc, ended_at: Time.now.utc
          )
        end
        state = node&.element_id == "End_reject" ? "terminated" : "completed"
        inst.update!(state: state, ended_at: Time.now.utc)
      end

      def find_job(params)
        id = params["job_id"]
        return [nil, refuse(:job_id_required, "job_id is required")] if id.nil?

        job = Vv::BpmnBbo::Run::Job.find_by(id: id)
        return [nil, refuse(:job_missing, "job #{id} does not exist")] unless job

        [job, nil]
      end

      def ok_instance(inst)
        open = inst.jobs.where(state: %w[open claimed]).order(:id)
        { ok: true,
          process_instance_id: inst.id,
          state: inst.state,
          jobs: open.map { |j| job_row(j) } }
      end

      def job_row(job)
        { "id" => job.id, "element_id" => job.flow_node.element_id, "kind" => job.kind,
          "state" => job.state, "name" => job.flow_node.name,
          "process_instance_id" => job.process_instance_id }
      end

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
    end
  end
end
