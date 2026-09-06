# frozen_string_literal: true

module Vv
  module Routing
    # WHICH PLANE A CALL IS ON, which is the question the two-tier literature
    # does not ask.
    #
    # The argument for cheap routing (docs/MonolitheLlmDead.md) is that tool
    # calling is "a mechanical syntax task, not an abstract reasoning problem",
    # so a small MoE does it at a fraction of the cost. True, and it decides
    # nothing on its own, because it leaves out the variable that actually
    # governs the risk: WHO CHECKS THE OUTPUT.
    #
    #   SYNTHESIS  the model's output is code, a plan, a shape, a migration --
    #              something that will be READ AND RUN LATER. It passes a
    #              compiler, a spec, a sweep, a review. A wrong answer here is
    #              caught by machinery that already exists, so routing it to the
    #              cheapest adequate tier costs a retry, not an incident.
    #
    #   PRODUCTION the code already exists and is executing. The model is inside
    #              a live request: MIND deriving a reading, SWITCH answering a
    #              completion, BUS carrying an event. Nothing downstream reads
    #              the output before someone depends on it. A wrong answer is a
    #              wrong answer that shipped.
    #
    # The distinction is not about model quality. It is about whether a verifier
    # stands between the model and the consequence. On the synthesis plane the
    # verifier is structural and free; on the production plane it has to be named
    # or it does not exist -- which is what Route refuses to leave unstated.
    class Plane
      NAMES = %i[synthesis production].freeze

      MEANS = {
        synthesis: "output is code, plan or structure, read and run later",
        production: "output is consumed live, inside a running request"
      }.freeze

      # What stands between the model and the consequence, by default.
      VERIFIED_BY = {
        synthesis: "the toolchain that already exists: syntax check, specs, " \
                   "sweep gates, review before merge",
        production: "nothing, unless a verifier is named"
      }.freeze

      class UnknownPlane < ArgumentError; end

      attr_reader :name

      def initialize(name)
        name = name.to_sym
        raise UnknownPlane, "#{name.inspect} is not a plane; expected #{NAMES.inspect}" unless
          NAMES.include?(name)

        @name = name
      end

      def synthesis? = @name == :synthesis
      def production? = @name == :production
      def means = MEANS.fetch(@name)
      def verified_by = VERIFIED_BY.fetch(@name)

      # On synthesis the verifier is structural. On production it is a claim
      # someone has to make.
      def verifier_implicit? = synthesis?

      def ==(other) = other.is_a?(Plane) && other.name == @name
      alias eql? ==
      def hash = @name.hash
      def to_s = @name.to_s

      def self.all = NAMES.map { |n| new(n) }
      def self.synthesis = new(:synthesis)
      def self.production = new(:production)
    end
  end
end
