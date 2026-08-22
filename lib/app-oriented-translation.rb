# frozen_string_literal: true

require_relative "app_oriented_translation/version"

# Oriented Translation - a governed surface for Orientation, Meaning Clarification
# and Stewardship Translation, designed on the OSI Level 8 datatypes.
#
# The design vocabulary below is the substance of this gem. The Rails engine it
# now carries adds exactly one thing: a SHARED page shell
# (app/views/layouts/app_oriented_translation/application.html.erb) so every
# surface that renders a Profile 9 ACIA document renders through the same file.
# That is presentation, not implementation -- no ACIA document is authored,
# altered, or digested here.
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

# The renderer is usable without Rails booted (the static build scripts call it
# directly); the Engine only registers the same views with a host application.
require_relative "app_oriented_translation/page_renderer"
require_relative "app_oriented_translation/engine" if defined?(::Rails::Engine)
