# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Sdlc
    # The AgentTask process from AiSDLC.md, as rows, not XML.
    #
    # Agent 70% (draft + easy tests) is a SERVICE. The independent reality
    # test is a different service. Human review is a USER task that cannot
    # be skipped: the engine only advances from the current job. Observability
    # is a gate after accept, not a comment.
    module Seed
      PACKAGE_KEY = "sdlc"
      PROCESS_ID = "AgentTask"
      VERSION = "1"

      module_function

      def call
        Vv::BpmnBbo.seed_datatypes
        pkg = Vv::BpmnBbo::Package.find_or_create_by!(definition_key: PACKAGE_KEY) do |p|
          p.name = "AI-in-SDLC"
        end
        ver = Vv::BpmnBbo::DefinitionVersion.find_by(package_id: pkg.id, version: VERSION)
        if ver
          return { ok: true, already: true, definition_key: PACKAGE_KEY, version: VERSION,
                   process_id: PROCESS_ID }
        end

        ver = Vv::BpmnBbo::DefinitionVersion.create!(
          package: pkg, version: VERSION, source_digest: "sha256:sdlc-seed-v1",
          exporter: "hand", is_latest: true
        )
        proc = Vv::BpmnBbo::Process.create!(
          definition_version: ver, element_id: PROCESS_ID, name: "Agent task",
          is_executable: true
        )

        start = Vv::BpmnBbo::StartEvent.create!(process: proc, element_id: "Start_1", name: "Goal")
        draft = Vv::BpmnBbo::ServiceTask.create!(process: proc, element_id: "AgentDraft",
                                                 name: "Agent drafts the 70%")
        tests = Vv::BpmnBbo::ServiceTask.create!(process: proc, element_id: "AgentTests",
                                                 name: "Agent writes easy tests (not evidence)")
        reality = Vv::BpmnBbo::ServiceTask.create!(process: proc, element_id: "RealityTest",
                                                   name: "Independent reality / contract test")
        review = Vv::BpmnBbo::UserTask.create!(process: proc, element_id: "HumanReview",
                                               name: "Human reviews the diff")
        gw = Vv::BpmnBbo::ExclusiveGateway.create!(process: proc, element_id: "GwReview",
                                                   name: "Review verdict?", gateway_direction: "diverging")
        obs = Vv::BpmnBbo::ServiceTask.create!(process: proc, element_id: "ObsCheck",
                                               name: "Observability present")
        end_ok = Vv::BpmnBbo::EndEvent.create!(process: proc, element_id: "End_ok", name: "Shipped")
        end_no = Vv::BpmnBbo::EndEvent.create!(process: proc, element_id: "End_reject", name: "Rejected")

        flow = lambda do |eid, src, tgt, cond = nil|
          Vv::BpmnBbo::SequenceFlow.create!(
            process: proc, element_id: eid, source: src, target: tgt,
            condition_expression: cond
          )
        end

        flow.call("f_start", start, draft)
        flow.call("f_draft", draft, tests)
        flow.call("f_tests", tests, reality)
        flow.call("f_reality", reality, review)
        flow.call("f_to_gw", review, gw)

        reject_expr = Vv::BpmnBbo::Expression.create!(
          definition_version: ver, kind: "formal_expression", body: "reject", language: "hand"
        )
        flow.call("f_reject", gw, end_no, reject_expr)
        default = flow.call("f_accept", gw, obs)
        gw.update!(default_flow: default)
        flow.call("f_obs", obs, end_ok)

        { ok: true, already: false, definition_key: PACKAGE_KEY, version: VERSION,
          process_id: PROCESS_ID, node_count: proc.flow_nodes.count }
      rescue ::StandardError => e
        { ok: false, reason: :seed_failed, because: "#{e.class}: #{e.message}" }
      end
    end
  end
end
