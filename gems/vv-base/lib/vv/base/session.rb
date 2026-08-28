# frozen_string_literal: true

module Vv
  module Base
    # THE CYBORG SESSION -- one entity, either kind of actor.
    #
    # A human's visit to FRONT and the MIND loop reasoning about it are the SAME
    # session, because Level 8 is about the pairing rather than about either half.
    # Splitting this into HumanSession and AgentSession would put the pairing in a
    # join table, where it becomes a thing you can forget to look at.
    #
    # WHAT A SESSION IS FOR: it names a graph. Everything BACK projects and
    # everything MIND proposes during the session lands in ONE named graph that
    # resolves back to this row, so "what did this session see and do" is a query
    # rather than a reconstruction.
    #
    # WHAT IT IS NOT: authorization. actor_id is asserted by the caller -- the pod
    # has no authentication -- so a Session identifies a scope, not a principal.
    # P6 authorization-evidence is NOT satisfied by a session existing. Anything
    # that needs a proven actor must say so and fail closed until there is one.
    class Session < Record
      ACTOR_KINDS = %w[human agent].freeze
      STATES      = %w[open closed].freeze

      belongs_to :actor, class_name: "Vv::Base::Actor", optional: true

      validates :actor_kind, presence: true, inclusion: { in: ACTOR_KINDS }
      validates :state,      presence: true, inclusion: { in: STATES }

      scope :open_sessions, -> { where(state: "open") }

      # The named graph this session owns. DERIVED from the primary key and never
      # supplied, for the same reason Mmg::Graph::Entry#graph_name is derived: a
      # caller that could name its own graph could write into someone else's, or
      # into one that resolves to no record at all.
      def session_iri
        raise "unsaved session has no graph" if id.nil?

        "urn:mm:session:#{id}"
      end

      # Monotonic per-session counter. Every reading quotes the generation it read,
      # so a proposal can say WHICH state of the session it is about -- a reading
      # that cannot name its ground is a claim about nothing.
      def bump_generation!
        with_lock { update!(generation: generation.to_i + 1) }
        generation
      end

      def open?   = state == "open"
      def closed? = state == "closed"

      def close!
        return self if closed?

        update!(state: "closed", closed_at: Time.now.utc)
        self
      end
    end
  end
end
