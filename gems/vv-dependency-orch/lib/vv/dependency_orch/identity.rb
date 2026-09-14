# frozen_string_literal: true

module Vv
  module DependencyOrch
    # The one place a tag is refused.
    #
    # "Tags are not identity and are never stored as such" is the model's first
    # rule, and a rule enforced in several places is a rule enforced in none.
    # Every path that needs identity comes through `require!`, so there is
    # exactly one line to plant a gate against.
    #
    # Named Identity rather than Digest on purpose: `::Digest` is stdlib, and a
    # `Digest` inside this namespace would shadow it for every file that later
    # wants a SHA. That is a five-minute bug with an hour-long diagnosis.
    module Identity
      OCI = /\Asha256:([0-9a-f]{64})\z/
      OCI_NAMED = /\A(?<name>[\w.\-\/:]+?)@(?<digest>sha256:[0-9a-f]{64})\z/
      GIT = /\A([0-9a-f]{40})\z/

      # A prefix a human types. Never an identity -- only ever a lookup key, and
      # `require!` refuses it so the two uses cannot be confused.
      OCI_PREFIX = /\Asha256:([0-9a-f]{6,63})\z/
      GIT_PREFIX = /\A([0-9a-f]{7,39})\z/

      # `name:tag`, `name`, `repo/name:tag`. What a human reaches for and what
      # must never key a resource.
      TAGGED = /\A[\w.\-\/]+:[\w.\-]+\z/

      module_function

      # Parses a reference into { digest:, kind:, name: } or refuses.
      #
      # kind is :oci or :git. `name` is the label observed alongside the digest
      # -- "rails-base" out of "rails-base@sha256:..." -- and it is carried as a
      # LABEL, never as the key. That is the distinction published_images.json
      # already makes in its own words: a mutable tag is not a pin.
      def parse(reference)
        ref = reference.to_s.strip
        return Envelope.refuse("malformed_digest", "empty reference") if ref.empty?

        if (m = OCI.match(ref))
          return Envelope.ok(digest: "sha256:#{m[1]}", kind: :oci, name: nil)
        end

        if (m = OCI_NAMED.match(ref))
          # "rails-base:1.2@sha256:..." -- the tag half is dropped, deliberately.
          # It was true when observed and is not identity, and keeping it in the
          # name field is how it later gets used as one.
          return Envelope.ok(digest: m[:digest], kind: :oci, name: m[:name].split(":").first)
        end

        if (m = GIT.match(ref))
          return Envelope.ok(digest: m[1], kind: :git, name: nil)
        end

        # A TRUNCATED DIGEST LOOKS EXACTLY LIKE A TAG, and this check has to come
        # first or every short digest a human types is refused as one.
        # "sha256:8db4d39f" satisfies TAGGED -- name, colon, word -- and calling
        # it a tag would be both wrong and unhelpful, since the caller did the
        # right thing and only abbreviated. It is still not an identity: a
        # prefix is a lookup key, and `resolve` is where prefixes are matched.
        if OCI_PREFIX.match?(ref) || GIT_PREFIX.match?(ref)
          return Envelope.refuse(
            "malformed_digest",
            "#{ref.inspect} is a truncated digest. A prefix can be looked up but cannot be an " \
            "identity; supply the full digest to key a resource by it."
          )
        end

        if TAGGED.match?(ref)
          return Envelope.refuse(
            "tag_is_not_identity",
            "#{ref.inspect} is a tag. A tag is a label observed at a time, resolvable to a " \
            "digest and never the key. Resolve it first, then name the digest."
          )
        end

        Envelope.refuse(
          "malformed_digest",
          "#{ref.inspect} is neither sha256: + 64 hex nor a 40-hex git revision"
        )
      end

      # For paths that require identity and will not accept a lookup key.
      def require!(reference)
        parse(reference)
      end

      def identity?(reference)
        Envelope.ok?(parse(reference))
      end

      # Is this a prefix a human typed, rather than a full digest? Used only by
      # lookup, never by construction.
      def prefix?(reference)
        ref = reference.to_s.strip
        OCI_PREFIX.match?(ref) || GIT_PREFIX.match?(ref)
      end

      def short(digest)
        d = digest.to_s
        return d if d.length <= 19

        d.start_with?("sha256:") ? d[0, 19] : d[0, 12]
      end
    end
  end
end
