# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Vv
  module Mobile
    # Closed catalogs the mobile client already ships (Neeman / ghis-19).
    # An agent *names* a kind; it does not send markup. Unknown kinds refuse.
    #
    # Source of truth mirrored from rails-osi-level-8:
    #   Profile9::Vocabulary::COMPONENT_KINDS  (19)
    #   Ui::Catalog::TASK_KINDS                (12)
    module Catalog
      GHIS_19 = "ghis-19@1"
      GHIS_20 = "ghis-20@1"
      GHIS_21 = "ghis-21@1"
      TASK_VERSION = "task-s2@1"

      # 19 ACIA presentation widgets. Closed. Bumps are ghis-20/21, never in-place.
      ACIA_COMPONENTS = %w[
        PageShell PanelFrame SemanticText StatusBadge MetricStrip
        ContextBanner DrillDownCard DataList Timeline EvidencePanel
        DecisionForm ActionControl Disclosure FilterBar TabSet
        EmptyState RefusalNotice ScopeTrail ReferentBridge
      ].freeze

      GHIS_20_COMPONENTS = (ACIA_COMPONENTS + %w[DateInput]).freeze
      GHIS_21_COMPONENTS = (GHIS_20_COMPONENTS + %w[Input]).freeze

      # 12 AIUX intentions — jobs an agent puts in front of a human.
      # Data, not screens. Each compiles into ghis-19 (or ghis-20 for date).
      AIUX_INTENTIONS = [
        { "kind" => "task.table",          "job" => "list with columns",              "composedOf" => %w[PageShell DataList],                         "catalogVersion" => GHIS_19 },
        { "kind" => "task.form",           "job" => "structured collect",              "composedOf" => %w[PageShell DecisionForm ActionControl],        "catalogVersion" => GHIS_19 },
        { "kind" => "task.date",           "job" => "a date, not a string",            "composedOf" => %w[PageShell DateInput],                        "catalogVersion" => GHIS_20 },
        { "kind" => "task.confirm",        "job" => "irreversible yes/no",             "composedOf" => %w[PageShell SemanticText ActionControl],        "catalogVersion" => GHIS_19 },
        { "kind" => "task.status",         "job" => "progress / waiting",              "composedOf" => %w[PageShell StatusBadge],                       "catalogVersion" => GHIS_19 },
        { "kind" => "task.error",          "job" => "recoverable failure",             "composedOf" => %w[PageShell RefusalNotice],                     "catalogVersion" => GHIS_19 },
        { "kind" => "task.empty",          "job" => "no rows, said out loud",          "composedOf" => %w[PageShell EmptyState],                        "catalogVersion" => GHIS_19 },
        { "kind" => "task.approval",       "job" => "HumanReview of a digest",         "composedOf" => %w[PageShell SemanticText ActionControl],        "catalogVersion" => GHIS_19 },
        { "kind" => "task.preview",        "job" => "show a blob by sha256:",          "composedOf" => %w[PageShell SemanticText],                      "catalogVersion" => GHIS_19 },
        { "kind" => "task.choice",         "job" => "one of N",                        "composedOf" => %w[PageShell TabSet ActionControl],              "catalogVersion" => GHIS_19 },
        { "kind" => "task.progress_steps", "job" => "SDLC position",                   "composedOf" => %w[PageShell Timeline],                          "catalogVersion" => GHIS_19 },
        { "kind" => "task.citation",       "job" => "grounded claim",                  "composedOf" => %w[PageShell SemanticText ReferentBridge],       "catalogVersion" => GHIS_19 }
      ].freeze

      module_function

      def acia_components(version = GHIS_19)
        case version.to_s
        when GHIS_21 then GHIS_21_COMPONENTS
        when GHIS_20 then GHIS_20_COMPONENTS
        else ACIA_COMPONENTS
        end
      end

      def aiux_intentions
        AIUX_INTENTIONS
      end

      def intention(kind)
        AIUX_INTENTIONS.find { |i| i["kind"] == kind.to_s }
      end

      def acia_kind?(name, version: GHIS_19)
        acia_components(version).include?(name.to_s)
      end

      def aiux_kind?(name)
        AIUX_INTENTIONS.any? { |i| i["kind"] == name.to_s }
      end
    end
  end
end
