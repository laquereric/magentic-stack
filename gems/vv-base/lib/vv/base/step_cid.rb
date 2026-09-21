# frozen_string_literal: true

require "digest"

module Vv
  module Base
    # ADR 0074 decision 6. The step CID is DERIVED, never stored.
    #
    # G12's canonical line reads "Pages cite those CIDs" and named something
    # that did not exist: flow_steps carries step_key and route_key, no cid
    # column, and no derivation rule anywhere. This is the rule.
    #
    # WHY NOT A COLUMN. A stored cid is a second source of truth for an identity
    # the natural keys already determine, and it can drift from its own inputs --
    # rename a step_key, forget the backfill, and the row now asserts an identity
    # nothing else agrees with. That is ADR 0074's own Context in a new place:
    # not a missing field, a field that can silently be wrong.
    #
    # WHY NOT Intent::Projection's CID. That one hashes "#{klass}:#{record.id}:
    # #{digest}" -- a database id and the row's mutable attributes. It changes
    # when a row is re-seeded into a fresh database, and it cannot be computed by
    # anyone who does not already hold the row. A page that cites a step must be
    # able to name it before it has fetched it.
    #
    # The inputs are exactly the tuple that identifies a step across every
    # application: the bundle it belongs to, its journey, its flow, and its key.
    # Nothing mutable is in the digest, so re-seeding is a no-op and renaming a
    # title changes nothing.
    module StepCid
      PREFIX = "cid:sha256:"

      # Unit Separator. The join must be unambiguous or (bundle "a:b", journey
      # "c") and (bundle "a", journey "b:c") would collide, and a colon is the
      # one character these keys are most likely to contain -- si.subject and
      # cid:actor:… are both real. US cannot appear in a slug, and a key
      # carrying one is refused rather than silently producing a shared CID.
      SEPARATOR = "\u001F"

      module_function

      # Pure. No database, no row -- four strings in, one CID out.
      def for(bundle_key:, journey_key:, flow_key:, step_key:)
        parts = {
          bundle_key: bundle_key, journey_key: journey_key,
          flow_key: flow_key, step_key: step_key
        }.map { |name, value| component!(name, value) }

        PREFIX + Digest::SHA256.hexdigest(parts.join(SEPARATOR))
      end

      # The CID of a persisted step, by traversal. Convenience only: `for` is the
      # definition and this must agree with it.
      def of(step)
        flow = step.flow
        journey = flow.journey
        self.for(
          bundle_key: journey.bundle_key,
          journey_key: journey.journey_key,
          flow_key: flow.flow_key,
          step_key: step.step_key
        )
      end

      # Resolve a cited CID back to one step, within a bundle.
      #
      # A DERIVED identity cannot be indexed, so this computes rather than looks
      # up, and the scope is the bundle's steps. That is the cost of not storing
      # it, stated rather than hidden: seeds are tens of rows, and the honest
      # alternative -- a stored column -- buys an index and a way to be wrong.
      def resolve(cid, bundle_key:)
        return nil if cid.to_s.empty?

        FlowStep.joins(flow: :journey)
                .where(journeys: { bundle_key: bundle_key })
                .find { |step| of(step) == cid }
      end

      def component!(name, value)
        s = value.to_s
        raise ArgumentError, "#{name} is required to derive a step CID" if s.strip.empty?
        raise ArgumentError, "#{name} may not contain the CID separator" if s.include?(SEPARATOR)

        s
      end
    end
  end
end
