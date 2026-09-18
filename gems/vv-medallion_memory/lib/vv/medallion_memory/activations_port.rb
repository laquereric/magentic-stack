# frozen_string_literal: true

module Vv
  module MedallionMemory
    # ActivationsPort: MeaningActivations weight lookup (Primitive 3 inject).
    #
    # MeaningActivations live in mind-pod; this gem takes no Rails
    # dependency and talks to them only through here. weight_for returns a
    # Float in [-1.0, +1.0] or nil:
    #   nil  = not in the model (absent is not zero)
    #   0.0  = considered, not injected, still inspectable
    #   > 0  = injected
    # Negative weights are carried through and treated like zero by Serve
    # (suppressed, inspectable): an activation against injection is still
    # evidence, just not injected evidence.
    module ActivationsPort
      module_function

      def weight_for(_subject_iri)
        raise NotImplementedError, "an ActivationsPort scores a subject or answers nil"
      end
    end

    # Default port: no model wired, everything scores 1.0, the whole
    # assembled pack injects. Serve still partitions, so the shape is
    # honest even where the weights are not.
    class NullActivations
      def weight_for(_subject_iri) = 1.0
    end

    # Hash-backed port for specs and for callers that already hold weights.
    # Missing keys answer nil (unmodeled), never zero.
    class MapActivations
      def initialize(weights = {})
        @weights = weights.transform_keys(&:to_s)
      end

      def weight_for(subject_iri)
        @weights.fetch(subject_iri.to_s, nil)
      end
    end
  end
end
