# frozen_string_literal: true

# The session cycle. Never raises -- every path returns an envelope, because the
# seam's contract is {ok:true, ...} or {ok:false, reason:, because:}.
module SessionCycle
  PREVIEW_LIMIT = 60
  MAX_LIMIT     = 200

  module_function

  def open(params)
    kind = params["actor_kind"].presence || "human"
    unless Vv::Base::Session::ACTOR_KINDS.include?(kind)
      return refuse(:unknown_actor_kind,
                    "actor_kind must be one of #{Vv::Base::Session::ACTOR_KINDS.join(', ')}; " \
                    "got #{kind.inspect}")
    end

    session = Vv::Base::Session.create!(
      actor_kind: kind, actor_id: params["actor_id"], state: "open", opened_at: Time.now.utc
    )

    { ok: true, session_id: session.id, session_iri: session.session_iri,
      actor_kind: session.actor_kind, generation: session.generation,
      # Said out loud because a Session looks like an identity and is not one:
      # the pod has no authentication, so the actor was asserted, not proven.
      actor_proven: false }
  rescue StandardError => e
    refuse(:open_failed, "#{e.class}: #{e.message}")
  end

  # WHICH session is in force. The harness's grounding step: everything
  # downstream quotes what this returns.
  #
  # The newest OPEN session, whoever opened it -- a human's visit on FRONT or an
  # agent loop. That is the point of one Session entity: MIND attaches to the
  # session already happening rather than talking only to itself.
  def latest(_params = {})
    session = Vv::Base::Session.open_sessions.order(id: :desc).first
    # Nothing open is not an error. It is the ordinary state of a pod nobody is
    # using yet, and MIND waits rather than inventing a session to reason about.
    return refuse(:no_open_session, "no session is open") unless session

    { ok: true, session_id: session.id, session_iri: session.session_iri,
      actor_kind: session.actor_kind, generation: session.generation,
      state: session.state }
  rescue StandardError => e
    refuse(:latest_failed, "#{e.class}: #{e.message}")
  end

  # A BOUNDED look at ONE session's graph.
  #
  # Scoped to GRAPH <session_iri>, never the whole store. The store is append-only
  # and holds every session ever opened, so an unscoped query would read across
  # sessions and return rows that look perfectly plausible while belonging to
  # someone else.
  def context(params)
    session = find_session(params["session_id"])
    return session if session.is_a?(Hash)

    limit = [[params["limit"].to_i, 1].max, MAX_LIMIT].min
    limit = PREVIEW_LIMIT if params["limit"].blank?

    sparql = <<~SPARQL
      SELECT ?s ?p ?o WHERE { GRAPH <#{session.session_iri}> { ?s ?p ?o } } LIMIT #{limit}
    SPARQL

    result = Mmg::Graph::Execute.query(sparql)
    return result unless result.is_a?(Hash) && result[:ok]

    { ok: true,
      session_iri: session.session_iri,
      # THE GROUND. Every reading quotes the generation it read, so a proposal can
      # say WHICH state of the session it is about. A reading that cannot name its
      # ground is a claim about nothing.
      generation: session.generation,
      state: session.state,
      rows: result[:rows] || [] }
  rescue StandardError => e
    refuse(:context_failed, "#{e.class}: #{e.message}")
  end

  # MIND proposes; BACK commits. The write goes through graph.publish, so it mints
  # its own grounded Entry and lands in the session's graph.
  def observe(params)
    session = find_session(params["session_id"])
    return session if session.is_a?(Hash)
    return refuse(:session_closed, "session #{session.id} is closed; its graph is append-only but sealed") if session.closed?

    title = params["title"].to_s
    body  = params["body"].to_s
    return refuse(:empty_observation, "an observation needs a title") if title.strip.empty?

    opid    = params["operationId"].to_s
    subject = "urn:mm:session:#{session.id}:observation:#{opid.presence || SecureRandom.hex(8)}"

    triples = [
      ntriple(subject, PodGraph::RDF_TYPE, "<#{PodGraph::VOCAB}CognitiveRecord>"),
      ntriple(subject, "#{PodGraph::VOCAB}title", literal(title)),
      ntriple(subject, "#{PodGraph::VOCAB}body",  literal(body)),
      # What it is a reading OF, and of WHICH state. Without the generation this
      # is an opinion with no subject.
      ntriple(subject, "#{PodGraph::VOCAB}aboutSession", "<#{session.session_iri}>"),
      ntriple(subject, "#{PodGraph::VOCAB}groundedIn", literal(session.generation.to_s)),
      # PROPOSED, not asserted as fact. MIND returns a proposal; BACK committing it
      # makes it durable, not true.
      ntriple(subject, "#{PodGraph::VOCAB}status", literal("proposed"))
    ]

    result = Mmg::Graph::Cpcp.publish(
      "date" => Time.now.utc.strftime("%Y-%m-%d"),
      "name" => "session #{session.id} observation",
      "description" => "MIND cognitive record for #{session.session_iri} at generation " \
                       "#{session.generation}: #{title}",
      "triples" => triples,
      "session_id" => session.id
    )
    return result unless result.is_a?(Hash) && result[:ok]

    session.bump_generation!
    result.merge(ok: true, session_iri: session.session_iri, subject: subject,
                 generation: session.generation)
  rescue StandardError => e
    refuse(:observe_failed, "#{e.class}: #{e.message}")
  end

  def close(params)
    session = find_session(params["session_id"])
    return session if session.is_a?(Hash)

    session.close!
    { ok: true, session_id: session.id, session_iri: session.session_iri,
      state: session.state, closed_at: session.closed_at&.iso8601 }
  rescue StandardError => e
    refuse(:close_failed, "#{e.class}: #{e.message}")
  end

  # --- helpers ---

  def find_session(id)
    return refuse(:session_id_required, "session_id is required") if id.blank?

    Vv::Base::Session.find_by(id: id) ||
      refuse(:unknown_session, "session #{id.inspect} does not exist")
  end

  def ntriple(subject, predicate, object) = "<#{subject}> <#{predicate}> #{object} ."

  # SPARQL literal escaping. A title carrying a quote or a newline would otherwise
  # end the literal early and change the shape of the INSERT -- the graph equivalent
  # of SQL injection, reached through a field MIND fills in.
  def literal(value)
    escaped = value.to_s
                   .gsub("\\", "\\\\\\\\")
                   .gsub('"', '\\"')
                   .gsub("\n", '\\n')
                   .gsub("\r", '\\r')
                   .gsub("\t", '\\t')
    "\"#{escaped}\""
  end

  def refuse(reason, because) = { ok: false, reason: reason, because: because }
end
