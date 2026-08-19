# The CPCP projection: BACK's /_cpcp seam is the ONLY write path (sole writer).
RailsCpcp.base_iri = ENV.fetch("BASE_IRI", "https://mind-pod.local")

RailsCpcp.project(model: "Note") do
  operation "note.list",   direction: :pull, result: :collection, summary: "List notes",
    via: ->(_p, _c) { Note.order(created_at: :desc).limit(50).map(&:as_api) }
  operation "note.get",    direction: :pull, params: %w[id], summary: "Get one note",
    via: ->(p, _c) { Note.find(p["id"]).as_api }
  operation "note.create", direction: :push, params: %w[title body], summary: "Create a note",
    via: ->(p, _c) { Note.create!(title: p["title"], body: p["body"]).as_api }
end

RailsCpcp.project(model: "Reconciliation") do
  operation "reconciliation.latest", direction: :pull, summary: "Latest BACKJOB reconciliation",
    via: ->(_p, _c) { Reconciliation.order(created_at: :desc).first&.as_api || {} }
end
