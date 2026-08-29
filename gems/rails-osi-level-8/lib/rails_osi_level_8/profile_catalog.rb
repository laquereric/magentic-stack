# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  # Skeleton catalog of closed-shape entries keyed by request/response shape name.
  # Shape digests are pinned at load so a shape correction is visible in evidence.
  class ProfileCatalog
    # sha256 is the LEGACY shape_digest: bare SHA-256 of exact runtime-root
    # file bytes. Do not prefix it; do not canonicalize; do not reinterpret.
    # v2 and artifact_id are additive dual-write fields.
    Entry = Data.define(:id, :path, :shape_iri, :sha256, :shape_name, :compiler_sha256) do
      def shape_digest_v2
        {
          "algorithm" => "sha256",
          "value" => sha256,
          "covers" => "source shape text: exact bytes of #{File.basename(path.to_s)} " \
                      "under config.shape_root; not canonicalized RDF; not the compiled Ruby backend"
        }
      end

      def shape_artifact_id
        # Compiled/executable artifact identity. Distinct from source file digest:
        # two shapes that share a TTL file (identical source bytes) MUST NOT collide.
        "shape-artifact:ruby/grounding/#{shape_name}@sha256:#{compiler_sha256}"
      end
    end

    PROFILE_IDS = {
      "P1" => "osi-l8/p1/cyborg-channel@1",
      "P4" => "osi-l8/p4-durable-execution@1",
      "P9" => "osi-level-8/profile-9",
      "P11" => "osi-level-8/profile-11"
    }.freeze

    def self.default(root = RailsOsiLevel8.config.shape_root)
      root = Pathname(root) if root
      raise ArgumentError, "shape_root required" unless root

      mapping = {
        "P1::NoteCreateEffectShape"  => ["P1", "profile-1-cyborg-channel.ttl", "https://osi.example/shapes/P1NoteCreateEffectShape"],
        "P1::NoteCreateContextShape" => ["P1", "profile-1-cyborg-channel.ttl", "https://osi.example/shapes/P1NoteCreateContextShape"],
        "P1::NoteListPullShape"      => ["P1", "profile-1-cyborg-channel.ttl", "https://osi.example/shapes/P1NoteListPullShape"],
        "P1::NoteListContextShape"   => ["P1", "profile-1-cyborg-channel.ttl", "https://osi.example/shapes/P1NoteListContextShape"],
        "P4::NoteCreateEffectShape"  => ["P4", "profile-4-durable-execution.ttl", "https://osi.example/shapes/P4NoteCreateEffectShape"],
        "P4::DurableReceiptShape"    => ["P4", "profile-4-durable-execution.ttl", "https://osi.example/shapes/P4DurableReceiptShape"],

        # The session cycle. The shape FILE is the specification -- CI runs pyshacl
        # over it with valid/invalid fixtures -- while Grounding carries the runtime
        # twin that actually refuses a live request, because the TTL is not executed
        # in-process. Registering a name here WITHOUT that twin now refuses rather
        # than silently validating clean.
        "P1::SessionOpenEffectShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionOpenEffectShape"],
        "P1::SessionContextPullShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionContextPullShape"],
        "P1::SessionObserveEffectShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionObserveEffectShape"],
        "P1::SessionCloseEffectShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionCloseEffectShape"],
        "P1::SessionLatestPullShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionLatestPullShape"],
        "P1::SessionOpenContextShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionOpenContextShape"],
        "P1::SessionContextContextShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionContextContextShape"],
        "P1::SessionObserveContextShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionObserveContextShape"],
        "P1::SessionCloseContextShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionCloseContextShape"],
        "P1::SessionLatestContextShape" => ["P1", "session-operations.shacl.ttl", "https://w3id.org/cpcp/osi8/session#SessionLatestContextShape"]
      }.merge(p9_operation_shapes).merge(p11_operation_shapes)

      compiler = Pathname(__dir__).join("grounding.rb")
      compiler_sha256 = File.file?(compiler) ? Digest::SHA256.file(compiler).hexdigest : "unsigned"
      entries = mapping.to_h do |shape_name, (profile_key, filename, iri)|
        path = root.join(filename)
        digest = File.file?(path) ? Digest::SHA256.file(path).hexdigest : Digest::SHA256.hexdigest(filename)
        [shape_name, Entry.new(PROFILE_IDS.fetch(profile_key), path, iri, digest, shape_name, compiler_sha256)]
      end
      new(entries)
    end

    def initialize(entries)
      @entries = entries
    end

    def fetch(key) = @entries.fetch(key)
    def [](key) = @entries[key]
    def keys = @entries.keys

    # P9.5 — one catalog entry per Vocabulary::OPERATIONS request/response shape.
    # Derived from OPERATIONS so describe() cannot advertise an unregistered name.
    def self.p9_operation_shapes
      unless defined?(::RailsOsiLevel8::Profile9::Vocabulary)
        require_relative "profile9/vocabulary"
      end
      vocab = ::RailsOsiLevel8::Profile9::Vocabulary
      vocab::OPERATIONS.flat_map { |op| [op[:request_shape], op[:response_shape]] }.uniq.to_h do |name|
        local = name.to_s.sub(/\AP9::/, "")
        [name, ["P9", vocab::SHAPE_FILE, "#{vocab::VOCAB_IRI}#{local}"]]
      end
    end
    private_class_method :p9_operation_shapes

    def self.p11_operation_shapes
      unless defined?(::RailsOsiLevel8::Profile11::Vocabulary)
        require_relative "profile11/vocabulary"
      end
      vocab = ::RailsOsiLevel8::Profile11::Vocabulary
      vocab::OPERATIONS.flat_map { |op| [op[:request_shape], op[:response_shape]] }.uniq.to_h do |name|
        local = name.to_s.sub(/\AP11::/, "")
        [name, ["P11", vocab::SHAPE_FILE, "#{vocab::VOCAB_IRI}#{local}"]]
      end
    end
    private_class_method :p11_operation_shapes
  end
end
