# frozen_string_literal: true

# Vv::Base::Session projects like any other application state.
#
# DECLARED HERE, NOT IN THE GEM. vv-base is the canonical model home and has no
# dependency on vv-graph; adding one would couple every host that wants canonical
# models to the RDF projection whether or not it runs a graph. Which models this
# pod projects is the POD's policy, so it lives in the pod.
#
# BACK only: FRONT has no database, and a projection is a write.
Rails.application.config.to_prepare do
  next unless ENV.fetch("ROLE", "back") == "back"
  next if Vv::Base::Session.respond_to?(:semantica_triples_declaration) &&
          Vv::Base::Session.semantica_triples_declaration

  Vv::Base::Session.include(Vv::Graph::Storable)
  Vv::Base::Session.class_eval do
    triples do
      graph   PodGraph::STATE
      subject -> { "urn:mm:session:#{id}" }
      triple PodGraph::RDF_TYPE,      "<#{PodGraph::VOCAB}Session>"
      triple "#{PodGraph::VOCAB}actorKind",  -> { actor_kind }
      triple "#{PodGraph::VOCAB}state",      -> { state }
      triple "#{PodGraph::VOCAB}generation", -> { generation }
      triple "#{PodGraph::VOCAB}openedAt",   -> { opened_at&.iso8601 }
      triple "#{PodGraph::VOCAB}closedAt",   -> { closed_at&.iso8601 }, if: -> { closed_at.present? }
      # The session node lives in the STATE graph and NAMES its own graph, so a
      # reader that finds the session can find its contents without being told
      # the naming convention.
      triple "#{PodGraph::VOCAB}sessionGraph", -> { "<#{PodGraph.session_graph(id)}>" }
    end
    project_on_save!
  end
end
