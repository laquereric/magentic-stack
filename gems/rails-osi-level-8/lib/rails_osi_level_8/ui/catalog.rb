# frozen_string_literal: true

module RailsOsiLevel8
  module Ui
    # Presentation kinds (ghis-19) + the four S2 task jobs.
    # Not a fourth Flow. task.form is a Page job whose fields are F2.
    module Catalog
      TASK_VERSION = "task-s2@1"
      TASK_KINDS = [
        {
          "kind" => "task.form",
          "job" => "structured collect",
          "composedOf" => %w[PageShell DecisionForm ActionControl]
        },
        {
          "kind" => "task.confirm",
          "job" => "irreversible yes/no",
          "composedOf" => %w[PageShell SemanticText ActionControl]
        },
        {
          "kind" => "task.error",
          "job" => "recoverable failure",
          "composedOf" => %w[PageShell RefusalNotice]
        },
        {
          "kind" => "task.empty",
          "job" => "no rows",
          "composedOf" => %w[PageShell EmptyState]
        },
        {
          "kind" => "task.approval",
          "job" => "HumanReview accept/reject",
          "composedOf" => %w[PageShell SemanticText ActionControl]
        },
        {
          "kind" => "task.preview",
          "job" => "show a blob (PNG, JSON) by digest",
          "composedOf" => %w[PageShell SemanticText]
        },
        {
          "kind" => "task.date",
          "job" => "a date, not a string",
          "composedOf" => %w[PageShell DateInput],
          "catalogVersion" => "ghis-20@1"
        }
      ].freeze

      module_function

      def get(_params = {})
        {
          "presentation" => {
            "version" => Profile9::Compile::CATALOG_VERSION,
            "kinds" => Profile9::Vocabulary::COMPONENT_KINDS.dup,
            "versions" => {
              "ghis-19@1" => Profile9::Vocabulary::COMPONENT_KINDS.dup,
              "ghis-20@1" => Profile9::Vocabulary::GHIS_20_KINDS.dup,
              "ghis-21@1" => Profile9::Vocabulary::GHIS_21_KINDS.dup
            }
          },
          "task" => {
            "version" => TASK_VERSION,
            "kinds" => TASK_KINDS
          }
        }
      end
    end
  end
end
