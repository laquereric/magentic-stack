# frozen_string_literal: true
module RailsOsiLevel8
  # Grounding = SHACL validation + profile evidence. Validates a Context/Effect record
  # (after JSON-LD expansion) against the active profile's CLOSED shapes BEFORE admission
  # to a ledger or before acting. Non-conforming => never-raise refusal. Uses mm-shacl-reader
  # against the osi-level-8 profile-*.ttl shapes. TODO(build): wire Mm::ShaclReader + shapes_path.
  module Grounding
    module_function
    def validate(graph, profile: RailsOsiLevel8.config.profile)
      Envelope.fail(reason: :not_implemented,
                    because: "Grounding.validate - SHACL via mm-shacl-reader against osi-level-8 profile-#{profile} shapes (see docs/CHARTER.md)")
    end
  end
end
