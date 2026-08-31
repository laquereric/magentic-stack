# frozen_string_literal: true
require "json"
require_relative "rails_cpcp/version"
require_relative "rails_cpcp/registry"
require_relative "rails_cpcp/dsl"
require_relative "rails_cpcp/idempotency"
require_relative "rails_cpcp/envelope"
require_relative "rails_cpcp/request_body"
require_relative "rails_cpcp/replay"
require_relative "rails_cpcp/dispatcher"
require_relative "rails_cpcp/cid"
require_relative "rails_cpcp/engine" if defined?(::Rails::Engine)

# rails-cpcp -- an ADDITIVE Rails engine that projects selected Rails resources
# as CID-grounded JSON-RPC-LD (CPCP / PubSubStandard_1) PULL/PUSH operations,
# so a conventional Rails monolith can ALSO deploy as a mandatory two-pod CPCP
# pod (Rails = BACK, a thin separate FRONT). See README + deploy/deploy.cpcp.yml.
module RailsCpcp
end
