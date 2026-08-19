# frozen_string_literal: true

require_relative "rails_osi_level_8/version"
require_relative "rails_osi_level_8/envelope"
require_relative "rails_osi_level_8/known_refusal"
require_relative "rails_osi_level_8/configuration"
require_relative "rails_osi_level_8/cid"
require_relative "rails_osi_level_8/ledger"
require_relative "rails_osi_level_8/ledger_policy"
require_relative "rails_osi_level_8/profile_catalog"
require_relative "rails_osi_level_8/grounding"
require_relative "rails_osi_level_8/grammar"
require_relative "rails_osi_level_8/cpcp_adapter"

# rails-osi-level-8 -- the OSI Level 8 cybernetic-interface grammar as a Rails engine,
# realized as a SEMANTIC ADAPTER ATOP CPCP (rails-cpcp). Context = perception (PULL),
# Effect = action (PUSH); grounded JSON-LD constrained by closed SHACL profile shapes;
# the three-ledger discipline; profile evidence (Profiles 1-8). It does NOT mount a second
# public RPC surface -- /_cpcp remains the single seam.
module RailsOsiLevel8; end

OsiLevel8 = RailsOsiLevel8 unless defined?(OsiLevel8)

# ActiveRecord models + projections load when Rails/AR is present (BACK).
if defined?(::ActiveRecord::Base)
  require_relative "rails_osi_level_8/models/record"
  require_relative "rails_osi_level_8/models/governed_record"
  require_relative "rails_osi_level_8/models/context"
  require_relative "rails_osi_level_8/models/cyborg_channel"
  require_relative "rails_osi_level_8/models/operation_request"
  require_relative "rails_osi_level_8/models/operation_journal_entry"
  require_relative "rails_osi_level_8/models/execution_receipt"
  require_relative "rails_osi_level_8/models/admission_attempt"
  require_relative "rails_osi_level_8/models/reference_pass"
  require_relative "rails_osi_level_8/models/routing_decision"
  require_relative "rails_osi_level_8/models/routing_hop"
  require_relative "rails_osi_level_8/models/authorization_evidence"
  require_relative "rails_osi_level_8/models/observation"
  require_relative "rails_osi_level_8/models/outcome"
  require_relative "rails_osi_level_8/models/learning_event"
  require_relative "rails_osi_level_8/models/profile_evidence"
  require_relative "rails_osi_level_8/models/biography_event"
  require_relative "rails_osi_level_8/models/provenance_edge"
  require_relative "rails_osi_level_8/profile_index"
  require_relative "rails_osi_level_8/authorization"
  require_relative "rails_osi_level_8/routing"
  require_relative "rails_osi_level_8/references"
  require_relative "rails_osi_level_8/learning"
  require_relative "rails_osi_level_8/p7_commands"
  require_relative "rails_osi_level_8/projections"
  require_relative "rails_osi_level_8/fixtures"
end

require_relative "rails_osi_level_8/engine" if defined?(::Rails::Engine)
