# frozen_string_literal: true

# The pod's graph vocabulary, in one place.
#
# Storable wraps a predicate in <> VERBATIM -- it expands no prefixes -- so every
# predicate here is a full IRI. Writing "rdf:type" in a triples block produces the
# relative IRI <rdf:type>, which is not what anyone means and which no query will
# ever match.
module PodGraph
  # Application state: the deterministic BACK -> GRAPH arc. One graph, because
  # "the state of this pod" is one thing and a query for it should not have to
  # know how many graphs it was scattered across.
  STATE = "urn:mm:pod:state"

  VOCAB    = "urn:mm:vocab/pod#"
  RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  # A session's own graph. Kept identical to Vv::Base::Session#session_iri and
  # Mmg::Graph::Entry#session_graph_name -- three places derive this name and they
  # must agree, or a session's triples land somewhere nothing reads.
  def self.session_graph(session_id) = "urn:mm:session:#{session_id}"
end
