# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  # Skeleton catalog of closed-shape entries keyed by request/response shape name.
  # Shape digests are pinned at load so a shape correction is visible in evidence.
  class ProfileCatalog
    Entry = Data.define(:id, :path, :shape_iri, :sha256)

    PROFILE_IDS = {
      "P1" => "osi-l8/p1/cyborg-channel@1",
      "P4" => "osi-l8/p4-durable-execution@1",
      "P9" => "osi-level-8/profile-9"
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
        "P4::DurableReceiptShape"    => ["P4", "profile-4-durable-execution.ttl", "https://osi.example/shapes/P4DurableReceiptShape"]
      }.merge(p9_operation_shapes)

      entries = mapping.transform_values do |profile_key, filename, iri|
        path = root.join(filename)
        digest = File.file?(path) ? Digest::SHA256.file(path).hexdigest : Digest::SHA256.hexdigest(filename)
        Entry.new(PROFILE_IDS.fetch(profile_key), path, iri, digest)
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
  end
end
