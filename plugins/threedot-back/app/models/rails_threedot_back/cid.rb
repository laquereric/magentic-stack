# frozen_string_literal: true
module RailsThreedotBack
  # The CID: ROOT of all AR-driven threedot queries. The shell derives its live UI model from
  # here, NOT from the static cid.json (which is a bootstrap seed only).
  class Cid < ApplicationRecord
    self.table_name = "rails_threedot_back_cids"
    has_many :operations,   dependent: :destroy
    has_many :capabilities, dependent: :destroy
    has_many :shapes,       dependent: :destroy
    has_many :object_nodes, dependent: :destroy

    # Storable RDF projection is ENABLED here but DEFERRED at first cut (AR-primary now):
    #   include Vv::Graph::Storable
    #   triples do ... end
    # Enable when the RDF/SPARQL projection is needed; the AR surface above is authoritative first.

    def as_api
      { "@id" => cid_iri, "@type" => "threedot:Cid", "title" => title, "version" => version,
        "operations" => operations.map(&:name) }
    end
    def context_api = { "@id" => cid_iri, "title" => title,
                        "capabilities" => capabilities.map(&:as_api), "shapes" => shapes.map(&:as_api) }
  end
end
