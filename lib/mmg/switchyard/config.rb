# frozen_string_literal: true
module Mmg
  module Switchyard
    # A CID-derived Switchyard Config: what an LLM-assistance call is bound to.
    # source: :local (MLX, we own the KV) | :remote. Produced from a CID by the
    # CID-Config<->Switchyard contract; carries model, routing policy, and budget.
    Config = Struct.new(:cid_iri, :model, :source, :policy, :budget, :route, keyword_init: true)
  end
end
