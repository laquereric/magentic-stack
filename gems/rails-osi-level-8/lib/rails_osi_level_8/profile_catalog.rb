# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  # Closed-shape catalog keyed by request/response shape name.
  # ADR 0044: resolution is a per-shape map (gem + file), not config.shape_root.
  class ProfileCatalog
    Entry = Data.define(:id, :path, :shape_iri, :sha256, :shape_name, :compiler_sha256, :covers) do
      def shape_digest_v2
        {
          "algorithm" => "sha256",
          "value" => sha256,
          "covers" => covers
        }
      end

      def shape_artifact_id
        "shape-artifact:ruby/grounding/#{shape_name}@sha256:#{compiler_sha256}"
      end
    end

    PROFILE_IDS = {
      "P1" => "osi-l8/p1/cyborg-channel@1",
      "P4" => "osi-l8/p4-durable-execution@1",
      "P9" => "osi-level-8/profile-9",
      "P11" => "osi-level-8/profile-11"
    }.freeze

    APP = "shapes-application"
    L8 = "shapes-level-8"
    APP_MIND = "contracts/mind-pod"
    L8_BUNDLES = "bundles"

    # Protocol NodeShapes whose binding-manifest source_shape is the L8
    # bundle (execution: runtime). Catalog used to define L8 and never
    # resolve it; the live resolver then disagreed with the manifest about
    # the same gem. Keys are P11::<local_name> so they sit next to the
    # operation expansions without colliding.
    L8_PROTOCOL_MAP = {
      "P11::ActabilityReceiptShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#ActabilityReceiptShape"],
      "P11::ConceptShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#ConceptShape"],
      "P11::DefinitionRevisionShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#DefinitionRevisionShape"],
      "P11::DisputeResolutionShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#DisputeResolutionShape"],
      "P11::FederationAgreementShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#FederationAgreementShape"],
      "P11::OperationBindingShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#OperationBindingShape"],
      "P11::SemanticActivationShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#SemanticActivationShape"],
      "P11::SemanticAlignmentAssertionShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#SemanticAlignmentAssertionShape"],
      "P11::SemanticAttestationShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#SemanticAttestationShape"],
      "P11::SemanticDisputeShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#SemanticDisputeShape"],
      "P11::SemanticVerificationEvidenceShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#SemanticVerificationEvidenceShape"],
      "P11::StewardshipTranslationShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#StewardshipTranslationShape"],
      "P11::TranslationReviewShape" => [L8, "#{L8_BUNDLES}/profile-11-meaning.ttl", "P11", "https://w3id.org/cpcp/osi8/meaning#TranslationReviewShape"],
    }.freeze

    # shape -> [gem, relpath, profile_key, iri]
    # Ownership from the binding manifest. Do not re-decide here.
    SHAPE_MAP = {
      "P1::NoteCreateEffectShape"  => [APP, "#{APP_MIND}/profile-1-cyborg-channel.ttl", "P1", "https://osi.example/shapes/P1NoteCreateEffectShape"],
      "P1::NoteCreateContextShape" => [APP, "#{APP_MIND}/profile-1-cyborg-channel.ttl", "P1", "https://osi.example/shapes/P1NoteCreateContextShape"],
      "P1::NoteListPullShape"      => [APP, "#{APP_MIND}/profile-1-cyborg-channel.ttl", "P1", "https://osi.example/shapes/P1NoteListPullShape"],
      "P1::NoteListContextShape"   => [APP, "#{APP_MIND}/profile-1-cyborg-channel.ttl", "P1", "https://osi.example/shapes/P1NoteListContextShape"],
      "P4::NoteCreateEffectShape"  => [APP, "#{APP_MIND}/profile-4-durable-execution.ttl", "P4", "https://osi.example/shapes/P4NoteCreateEffectShape"],
      "P4::DurableReceiptShape"    => [APP, "#{APP_MIND}/profile-4-durable-execution.ttl", "P4", "https://osi.example/shapes/P4DurableReceiptShape"],
      "P1::SessionOpenEffectShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionOpenEffectShape"],
      "P1::SessionContextPullShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionContextPullShape"],
      "P1::SessionObserveEffectShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionObserveEffectShape"],
      "P1::SessionCloseEffectShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionCloseEffectShape"],
      "P1::SessionLatestPullShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionLatestPullShape"],
      "P1::SessionOpenContextShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionOpenContextShape"],
      "P1::SessionContextContextShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionContextContextShape"],
      "P1::SessionObserveContextShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionObserveContextShape"],
      "P1::SessionCloseContextShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionCloseContextShape"],
      "P1::SessionLatestContextShape" => [APP, "#{APP_MIND}/session-operations.shacl.ttl", "P1", "https://w3id.org/cpcp/osi8/session#SessionLatestContextShape"]
    }.freeze

    SPLIT_FROM = {
      "profile-9-ghis.ttl" => "gems/rails-osi-level-8/data/osi-level-8/profile-9-ghis.ttl",
      "profile-11-meaning.ttl" => "gems/rails-osi-level-8/data/osi-level-8/profile-11-meaning.ttl"
    }.freeze

    def self.repo_root
      Pathname(__dir__).expand_path.join("../../../../")
    end

    def self.resolve(gem_name, rel)
      loaded = Gem.loaded_specs[gem_name] if defined?(Gem) && Gem.respond_to?(:loaded_specs)
      base = loaded ? Pathname(loaded.full_gem_path) : repo_root.join("gems", gem_name)
      base.join(rel)
    end

    def self.covers_for(rel, path)
      base = File.basename(rel)
      if SPLIT_FROM.key?(base)
        "source shape text: exact bytes of #{rel}; previous file-level digest covered " \
          "#{SPLIT_FROM[base]} which no longer exists (ADR 0044); " \
          "not canonicalized RDF; not the compiled Ruby backend"
      else
        "source shape text: exact bytes of #{rel} (moved byte-identical from " \
          "gems/rails-osi-level-8/data/osi-level-8/#{base}); " \
          "not canonicalized RDF; not the compiled Ruby backend"
      end
    end

    def self.default(_ignored = nil)
      mapping = SHAPE_MAP.merge(L8_PROTOCOL_MAP).merge(p9_operation_shapes).merge(p11_operation_shapes)
      compiler = Pathname(__dir__).join("grounding.rb")
      compiler_sha256 = File.file?(compiler) ? Digest::SHA256.file(compiler).hexdigest : "unsigned"
      entries = mapping.to_h do |shape_name, (gem_name, rel, profile_key, iri)|
        path = resolve(gem_name, rel)
        digest = File.file?(path) ? Digest::SHA256.file(path).hexdigest : Digest::SHA256.hexdigest(rel)
        [shape_name, Entry.new(
          PROFILE_IDS.fetch(profile_key), path, iri, digest, shape_name, compiler_sha256,
          covers_for(rel, path)
        )]
      end
      new(entries)
    end

    def initialize(entries)
      @entries = entries
    end

    def fetch(key) = @entries.fetch(key)
    def [](key) = @entries[key]
    def keys = @entries.keys

    def self.p9_operation_shapes
      unless defined?(::RailsOsiLevel8::Profile9::Vocabulary)
        require_relative "profile9/vocabulary"
      end
      vocab = ::RailsOsiLevel8::Profile9::Vocabulary
      vocab::OPERATIONS.flat_map { |op| [op[:request_shape], op[:response_shape]] }.uniq.to_h do |name|
        local = name.to_s.sub(/\AP9::/, "")
        [name, [APP, "#{APP_MIND}/profile-9-ghis.ttl", "P9", "#{vocab::VOCAB_IRI}#{local}"]]
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
        [name, [APP, "#{APP_MIND}/profile-11-meaning.ttl", "P11", "#{vocab::VOCAB_IRI}#{local}"]]
      end
    end
    private_class_method :p11_operation_shapes
  end
end
