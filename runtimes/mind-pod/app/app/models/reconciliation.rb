class Reconciliation < ApplicationRecord
  include Vv::Graph::Storable

  triples do
    graph   PodGraph::STATE
    subject -> { "urn:mm:reconciliation:#{id}" }
    triple PodGraph::RDF_TYPE,     "<#{PodGraph::VOCAB}Reconciliation>"
    triple "#{PodGraph::VOCAB}noteCount", -> { note_count }
    triple "#{PodGraph::VOCAB}createdAt", -> { created_at&.iso8601 }
  end
  project_on_save!

  def as_api
    { "@id" => "#{RailsCpcp.base_iri}/reconciliation/#{id}", "@type" => "Reconciliation",
      "note_count" => note_count, "at" => created_at&.iso8601 }
  end
end
