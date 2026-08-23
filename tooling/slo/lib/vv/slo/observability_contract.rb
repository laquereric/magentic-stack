# frozen_string_literal: true
module Vv
  module Slo
    # Telemetry is a PUBLIC API. You do not silently break what a service
    # reports about itself. An agent emits exactly the telemetry the spec asked
    # for and nothing beyond it, so an unwritten requirement is an invisible
    # service.
    class ObservabilityContract
      # Forbidden as a FILTER, not a recommendation.
      FORBIDDEN = %w[authorization cookie set-cookie session_token api_key password email].freeze
      ENFORCEMENT_POINTS = %i[build runtime].freeze

      attr_reader :service, :environment, :owner, :required_attributes, :cardinality_limits

      def initialize(service:, environment:, owner:, required_attributes: [], cardinality_limits: {})
        @service = service.to_s
        @environment = environment.to_s
        @owner = owner.to_s
        @required_attributes = Array(required_attributes).map(&:to_s)
        @cardinality_limits = cardinality_limits || {}
      end

      def validate
        missing = []
        missing << "service" if service.empty?
        missing << "environment" if environment.empty?
        # Telemetry without an owner is useless at 3:12 AM.
        missing << "owner" if owner.empty?
        return fail_r(:identity_incomplete, missing) if missing.any?
        { ok: true, service: service, environment: environment, owner: owner,
          enforcementPoints: ENFORCEMENT_POINTS }
      end

      # Build-time check: does an emitted signal violate the contract?
      def check_signal(name:, attributes: {}, cardinality: {})
        offending = attributes.keys.map(&:to_s).select { |k| FORBIDDEN.include?(k.downcase) }
        return fail_r(:forbidden_attribute, offending) if offending.any?

        missing = required_attributes - attributes.keys.map(&:to_s)
        return fail_r(:required_attribute_missing, missing) if missing.any?

        # Cardinality explosion is a COST failure, not a style one.
        blown = cardinality.select { |label, n| cardinality_limits[label.to_s] && n > cardinality_limits[label.to_s] }
        return fail_r(:cardinality_exceeded, blown) if blown.any?

        { ok: true, signal: name }
      end

      private

      def fail_r(reason, because) = { ok: false, reason: reason, because: because }
    end
  end
end
