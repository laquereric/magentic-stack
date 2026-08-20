# frozen_string_literal: true

require_relative "app_oriented_translation/version"

# Oriented Translation - a governed surface for Orientation, Meaning Clarification
# and Stewardship Translation, designed on the OSI Level 8 datatypes.
#
# DESIGN ONLY at this version. This gem carries the charter, the design and the
# L8 modification proposals arising from it; there is no implementation here, and
# adding one before the design is accepted would prejudge the open questions in
# docs/l8-modifications.md.
module AppOrientedTranslation
  # Deliverables are typed L8 artifacts, not prose about them.
  INTENT_TYPES = %w[intent:Mission intent:Vision intent:Persona intent:Actor].freeze
  JOURNEY_TYPES = %w[c4:Journey ux:Flow].freeze

  # Profile 9's closed component vocabulary. A page mockup that needs a kind
  # outside this list is a finding to be proposed, never an invention.
  ACIA_KINDS = %w[
    PageShell PanelFrame SemanticText StatusBadge MetricStrip
    ContextBanner DrillDownCard DataList Timeline EvidencePanel
    DecisionForm ActionControl Disclosure FilterBar TabSet
    EmptyState RefusalNotice
  ].freeze

  # Profile 11 records this app is a human surface over.
  MEANING_RECORDS = %w[
    Concept DefinitionRevision SemanticAttestation
    OperationBinding SemanticActivation ActabilityReceipt
  ].freeze

  # Derived per request, never stored. There is no band to set.
  ACTABILITY_BANDS = %w[explorable plan-eligible effect-eligible].freeze
end
