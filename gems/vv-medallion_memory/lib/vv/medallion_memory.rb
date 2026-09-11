# frozen_string_literal: true

require_relative "medallion_memory/version"
require_relative "medallion_memory/refusal"
require_relative "medallion_memory/purpose"
require_relative "medallion_memory/tier"
require_relative "medallion_memory/provenance"
require_relative "medallion_memory/flow"
require_relative "medallion_memory/engine_binding"

module Vv
  # The write-manage-read memory product on the medallion engine.
  #
  # See docs/architecture/plan_vv_medallion_memory.md.
  #
  # WHAT IS HERE: the contract half. Tiers (three, and Platinum refused by name),
  # purposes (three siblings, none of them a rank), the closed refusal
  # vocabulary, the six Flow declarations, and the Bronze provenance envelope
  # with its generation bound.
  #
  # WHAT IS NOT HERE, AND WHY: the engine. No Conformer, no Curator, no
  # projection. The plan blocks M1-M10 on an owner decision it states twice --
  # where mmg-medallion lives -- and names "forking mmg-medallion into this gem"
  # as a non-goal. EngineBinding.bind! refuses medallion_home_undecided so that
  # blocker is something callers hit rather than something they have to remember.
  #
  # Everything here was written to be true under EITHER answer to that question.
  # None of it has to be renegotiated when the home is named.
  module MedallionMemory
    module_function

    # The one-sentence frame, kept where the code is rather than only in the
    # plan, because the shortest description of this gem is the one most likely
    # to drift: it is the pipeline CONTRACT, not a new store. The stores are the
    # journal, vv-blob, oxigraph and Milvus, and all four already exist.
    def frame
      "the write-manage-read memory product on mmg-medallion's Build engine, running on " \
        "magentic-stack's journal, blob, graph and rag, served through ContextFrame " \
        "activations -- with Platinum kept out of Gold, and summarising on ingest refused by name"
    end

    # A single place to ask "may this land as Bronze?", so the cardinal sin has
    # one answer rather than one per caller.
    def may_land?(provenance)
      provenance.refusal || Refusal.ok(provenance: provenance.to_h)
    end
  end
end
