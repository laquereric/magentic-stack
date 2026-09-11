# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module BpmnBbo
    class EventDefinition < Record
      self.store_full_sti_class = true

      belongs_to :event, class_name: "FlowNode"
      belongs_to :message, optional: true
      belongs_to :signal, optional: true
      belongs_to :error, class_name: "BpmnError", optional: true
      belongs_to :escalation, optional: true
      belongs_to :condition_expression, class_name: "Expression", optional: true
      belongs_to :activity_ref, class_name: "FlowNode", optional: true
    end

    class MessageEventDefinition < EventDefinition; end
    class TimerEventDefinition < EventDefinition; end
    class ErrorEventDefinition < EventDefinition; end
    class SignalEventDefinition < EventDefinition; end
    class ConditionalEventDefinition < EventDefinition; end
    class EscalateEventDefinition < EventDefinition; end
    class CompensateEventDefinition < EventDefinition; end
    class LinkEventDefinition < EventDefinition; end
    class TerminateEventDefinition < EventDefinition; end
    class CancelEventDefinition < EventDefinition; end
  end
end
