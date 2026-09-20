# frozen_string_literal: true

require_relative "refusal"

module Vv
  module MedallionMemory
    # VectorPort: dense retrieval over merged subjects (Primitive 3 seed).
    #
    # The contract: embed is called on merge (Branch, Primitive 1 -- not
    # yet), search reads merged subjects only. Real Milvus writes stay
    # behind rag_write_undecided; InMemoryVector below is the test double
    # the specs run against, scored by token overlap so results are
    # deterministic without a model.
    module VectorPort
      module_function

      def embed(_subject_iri, _text)
        raise NotImplementedError, "a VectorPort embeds a subject's conformed text"
      end

      def search(_cue, _top_k = 20)
        raise NotImplementedError, "a VectorPort returns [[subject_iri, score]] best-first"
      end
    end

    # In-memory VectorPort. embed stores text per subject; search ranks by
    # token-overlap score (shared tokens over cue tokens), ties by
    # subject_iri so repeated calls are byte-identical. This is ANN
    # plumbing shape, not ANN quality -- quality is Milvus's job, later.
    #
    # Linked to a Store, embed refuses unmerged subjects (unmerged_embed):
    # embeddings index merged knowledge, and Branch.merge is the embedder
    # (it marks merged first, then embeds). Unlinked, the gate is off --
    # the pre-Branch specs embed steward seeds directly.
    class InMemoryVector
      def initialize(store: nil)
        @texts = {}
        @store = store
      end

      def embed(subject_iri, text)
        if !@store.nil? && !@store.merged?(subject_iri.to_s)
          return Refusal.build(
            Refusal::UNMERGED_EMBED,
            "embed on #{subject_iri} which is not merged: Branch.merge embeds after " \
            "it marks merged; embedding a branch would let rejected text haunt search"
          )
        end

        @texts[subject_iri.to_s] = text.to_s
        { ok: true, subject_iri: subject_iri.to_s }
      end

      def embedded?(subject_iri) = @texts.key?(subject_iri.to_s)

      def search(cue, top_k = 20)
        cue_tokens = tokenize(cue)
        return [] if cue_tokens.empty?

        scored = @texts.map do |subject_iri, text|
          overlap = (tokenize(text) & cue_tokens).size
          next nil if overlap.zero?

          [subject_iri, overlap.to_f / cue_tokens.size]
        end.compact
        scored.sort_by { |subject_iri, score| [-score, subject_iri] }.first(top_k).to_h
      end

      def clear!
        @texts.clear
        { ok: true }
      end

      private

      def tokenize(text)
        text.to_s.downcase.scan(/[a-z0-9]+/).uniq
      end
    end
  end
end
