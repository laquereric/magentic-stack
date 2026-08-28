class Note < ApplicationRecord
  include Vv::Graph::Storable

  validates :title, presence: true

  # DETERMINISTIC APPLICATION STATE, projected. The row stays the authority; this
  # is the graph's view of it (runtimes/graph/README.md: "BACK's store is the
  # canonical record; the graph is a PROJECTION of it").
  #
  # Full IRIs, not CURIEs: Storable wraps a predicate in <> verbatim and expands
  # nothing, so "rdf:type" would be written as the relative IRI <rdf:type>.
  triples do
    graph   PodGraph::STATE
    subject -> { "urn:mm:note:#{id}" }
    triple PodGraph::RDF_TYPE,     "<#{PodGraph::VOCAB}Note>"
    triple "#{PodGraph::VOCAB}title",     -> { title }
    triple "#{PodGraph::VOCAB}body",      -> { body }, if: -> { body.present? }
    triple "#{PodGraph::VOCAB}createdAt", -> { created_at&.iso8601 }
  end
  project_on_save!

  def as_api
    { "@id" => "#{RailsCpcp.base_iri}/note/#{id}", "@type" => "Note",
      "id" => id, "title" => title, "body" => body, "created_at" => created_at&.iso8601 }
  end
end
