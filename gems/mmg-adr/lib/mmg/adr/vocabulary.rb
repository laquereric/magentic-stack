# frozen_string_literal: true

module Mmg
  module Adr
    # The closed vocabulary for a decision record.
    #
    # Closed on purpose. An ADR index whose predicate set grows by accident is a
    # second place for architecture to drift, which is the exact failure this gem
    # exists to catch. A term that is not here cannot be projected.
    module Vocabulary
      module_function

      VOCAB      = "urn:mm:vocab/adr#"
      SUBJECT_NS = "urn:mm:adr:"
      CLASS_IRI  = "#{VOCAB}DecisionRecord"

      # Proposed -> Accepted -> Superseded. An accepted record is a ledger entry,
      # not a document: it is never edited, only superseded by a later one that
      # points back at it.
      STATUSES = %w[proposed accepted superseded].freeze
      TERMINAL = "superseded"

      # What an ADR can be ABOUT. Kept closed so "which subjects have no decision
      # record" stays a question with an answer.
      SUBJECT_KINDS = %w[protocol profile gem tooling].freeze

      # Single-valued literal attributes.
      SCALARS = {
        "adr_id"       => "#{VOCAB}adrId",
        "title"        => "#{VOCAB}title",
        "status"       => "#{VOCAB}status",
        "date"         => "#{VOCAB}date",
        "subject_kind" => "#{VOCAB}subjectKind",
        "subject"      => "#{VOCAB}subject",
        "source_path"  => "#{VOCAB}sourcePath",
        "body_digest"  => "#{VOCAB}bodyDigest"
      }.freeze

      # Multi-valued literal attributes. `paths` and `enforced_by` are the two
      # that carry the traceability chain: decision -> constraint -> code.
      LISTS = {
        "components"  => "#{VOCAB}component",
        "paths"       => "#{VOCAB}path",
        "enforced_by" => "#{VOCAB}enforcedBy"
      }.freeze

      # ADR-to-ADR edges. Object position is another ADR subject IRI.
      #
      # MULTI-VALUED. One decision can be replaced by two: an ADR that bundled a
      # settled decision with an open one is split, and each half gets the status
      # it has actually earned. A single-valued link would force naming one
      # successor and dropping the other -- the ledger lying to keep its schema.
      LINKS = {
        "supersedes"    => "#{VOCAB}supersedes",
        "superseded_by" => "#{VOCAB}supersededBy"
      }.freeze

      def subject_iri(adr_id) = "#{SUBJECT_NS}#{adr_id}"

      def status?(value)        = STATUSES.include?(value.to_s)
      def subject_kind?(value)  = SUBJECT_KINDS.include?(value.to_s)
    end
  end
end
