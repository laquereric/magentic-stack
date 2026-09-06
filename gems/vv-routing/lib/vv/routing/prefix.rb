# frozen_string_literal: true

require "digest"

module Vv
  module Routing
    # PREFIX DISCIPLINE. The cheap tier is only cheap if the prefix is stable.
    #
    # The source article's most useful operational claim: the cache discount
    # "applies strictly to identical prompt prefixes. If your agent loop
    # unpredictably mutates its system prompt or injects dynamic timestamps at
    # the start of the payload, your cache hit rate drops to zero percent."
    #
    # It is a cliff, not a slope. A prefix that is 99% identical is a miss, and
    # the failure is silent -- the calls still work, the bill just stops being
    # the one that justified the architecture. So this compares prefixes by
    # digest and names what moved.
    #
    # THIS DOES NOT PROMISE A DISCOUNT. Whether a given host honours prefix
    # caching, and at what rate, is the host's business and changes; SWITCH owns
    # that relationship here. What this can say is whether the prefix YOU sent
    # was stable, which is the half you control and the half that gets broken by
    # accident.
    module Prefix
      # Things that look stable and are not. A timestamp or a fresh uuid at the
      # head of a payload voids every hit after the first.
      VOLATILE = [
        [/\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/, "a timestamp"],
        [/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i, "a uuid"],
        [/\b\d{10,13}\b/, "an epoch-looking number"],
        [/\brequest[_-]?id\b/i, "a request id"]
      ].freeze

      module_function

      def digest(prefix) = Digest::SHA256.hexdigest(prefix.to_s)

      def stable?(first, second) = digest(first) == digest(second)

      # What is in this prefix that will make the next call miss?
      def volatile_parts(prefix)
        text = prefix.to_s
        VOLATILE.filter_map { |pattern, what| what if pattern.match?(text) }
      end

      # A prefix carrying anything volatile cannot be cached across turns, and
      # saying so before the bill does is the whole point.
      def cacheable?(prefix) = volatile_parts(prefix).empty?

      # Compare two turns and say plainly whether the discount survived.
      def audit(first, second)
        moved = !stable?(first, second)
        volatile = volatile_parts(first) | volatile_parts(second)
        {
          stable: !moved,
          digest_first: digest(first)[0, 12],
          digest_second: digest(second)[0, 12],
          volatile: volatile,
          verdict:
            if !moved && volatile.empty?
              "identical prefix; cacheable"
            elsif !moved
              "identical this time, but contains #{volatile.join(', ')} -- " \
              "it will move"
            else
              "prefix changed between turns; a partial match is a miss, " \
              "not a smaller discount"
            end
        }
      end
    end
  end
end
