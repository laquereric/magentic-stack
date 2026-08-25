# frozen_string_literal: true

module RailsOsiLevel8
  # Inherits Exception (not StandardError) so RailsCpcp::Dispatcher`s `rescue => e`
  # does not flatten us into handler_error; CpcpAdapter.install! maps us to a
  # never-raise envelope at the boundary.
  class KnownRefusal < Exception
    attr_reader :reason, :because

    def initialize(reason, because = {})
      @reason = reason.to_s
      @because = because.is_a?(Hash) ? because : { "detail" => because.to_s }
      super(@reason)
    end
  end
end
