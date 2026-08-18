# frozen_string_literal: true
require_relative "rails_osi_level_8/version"
require_relative "rails_osi_level_8/envelope"
require_relative "rails_osi_level_8/configuration"
require_relative "rails_osi_level_8/ledger"
require_relative "rails_osi_level_8/grounding"
require_relative "rails_osi_level_8/grammar"
require_relative "rails_osi_level_8/cpcp_adapter"
require_relative "rails_osi_level_8/engine" if defined?(::Rails::Engine)

# rails-osi-level-8 -- the OSI Level 8 cybernetic-interface grammar as a Rails engine,
# realized as a SEMANTIC ADAPTER ATOP CPCP (rails-cpcp). Context = perception (PULL),
# Effect = action (PUSH); grounded JSON-LD constrained by closed SHACL profile shapes;
# the three-ledger discipline; profile evidence (Profiles 1-8). It does NOT mount a second
# public RPC surface -- /_cpcp remains the single seam.
module RailsOsiLevel8; end
