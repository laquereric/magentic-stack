# frozen_string_literal: true

module RailsOsiLevel8
  # ONE RULE, WRITTEN ONCE: supplied-but-unusable is refused; absent keeps its
  # default.
  #
  # The write commands were built to fill in whatever the caller left out, which
  # is right for an ABSENT field -- execution_complete! omits measuredAt on
  # purpose, and a backjob has no callerIri to give. It is wrong for a SUPPLIED
  # one. `params["status"].presence || "achieved"` reads as a default and behaves
  # as an override: a caller who sends status "" gets "achieved" recorded, and a
  # caller who sends a non-object outcome gets `{"ok" => true}` -- a claim of
  # success it never made.
  #
  # The models already declare the closed sets (Outcome::STATUSES,
  # ExecutionReceipt's %w[succeeded failed refused], LearningEvent::EVENT_KINDS).
  # The defaults are what stop those validations from ever seeing the value.
  # These helpers restore the path to them.
  module SuppliedInput
    module_function

    # Refuse a key the caller SENT but left empty. Absent is untouched.
    def blank!(params, *keys)
      keys.each do |key|
        next unless params.key?(key)
        next unless params[key].to_s.strip.empty?

        raise KnownRefusal.new("missing_params", { "missing" => key })
      end
    end

    # Refuse a key the caller SENT as something other than an object, rather than
    # substituting one. Silently replacing it stores a value nobody supplied.
    def object!(params, *keys)
      keys.each do |key|
        next unless params.key?(key)
        next if params[key].nil? || params[key].is_a?(Hash)

        raise KnownRefusal.new("invalid_params", { "invalid" => key, "expected" => "object" })
      end
    end
  end
end
