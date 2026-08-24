# frozen_string_literal: true

require_relative "base/version"
require_relative "base/record"
require_relative "base/ledger_placed"
require_relative "base/actor"
require_relative "base/persona"
require_relative "base/mission"
require_relative "base/vision"
require_relative "base/journey"
require_relative "base/flow"
require_relative "base/engine" if defined?(Rails::Engine)

module Vv
  module Base
    BARE_NAMES = {
      "Actor" => Actor,
      "Persona" => Persona,
      "Mission" => Mission,
      "Vision" => Vision,
      "Journey" => Journey,
      "Flow" => Flow,
      "LedgerPlaced" => LedgerPlaced
    }.freeze

    # Opt-in top-level constants. Namespaced is the default because a gem
    # that claims Object::Actor will collide with the next host that has
    # one. Hosts that want the old mind-pod names call this once.
    def self.install_bare_constants!(into: Object)
      installed = []
      collisions = []
      BARE_NAMES.each do |name, klass|
        if into.const_defined?(name, false)
          collisions << name
        else
          into.const_set(name, klass)
          installed << name
        end
      end
      return { ok: false, reason: :constant_exists, because: collisions,
               installed: installed } if collisions.any?

      { ok: true, installed: installed }
    end
  end
end
