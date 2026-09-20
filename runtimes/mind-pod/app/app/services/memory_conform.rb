# frozen_string_literal: true

require "digest"
require "base64"

# S2: memory.conform. Bronze episode -> Silver facts, on BACK, triggered by
# BACKJOB polling completed memory.land operations (bin/backjob).
#
# One entity resolved across sessions: surface forms normalize and match
# (exact, or surname plus initial), so "Priya Raman" and "P. Raman" mint
# once and share one IRI. New claims supersede cleanly (M5: the old row's
# validTo closes, never overwritten); contradictions need a human and stay
# out of this stage. The new-facts batch runs the real mmg_shacl_v1 gate
# (M2), and the report persists on the receipt.
#
# Graph-side Silver only: rag upsert waits on rag_write_undecided, and
# entity resolution here is deterministic rules, not LLM extractors (both
# are named non-goals of this slice, not oversights). Relation extraction
# is one pattern (Name is [now] [my|a|the] role); broader IE is S2+.
#
# Pure Ruby: no ActiveRecord. The wire handler (call) does the Rails-side
# lookups (land request, receipt context, blob) and delegates the graph
# work to conform_episode, which is unit-testable without booting Rails.
# Time is world time (episode observed_at); the tx axis lives in the
# engine FactStore and arrives when conform runs there.
module MemoryConform
  SILVER_GRAPH = "urn:mm:medallion/memory.conform/silver/1"
  BRONZE_GRAPH = MemoryLand::BRONZE_GRAPH

  MENTION = /\b([A-Z][\p{L}]*\.?(?:\s+[A-Z][\p{L}]*\.?){0,2})\b/
  CLAIM = /\bis\s+(?:now\s+)?(?:my\s+|a\s+|the\s+)?([^.,!?;]+)/i

  STOPWORDS = %w[
    And The A An But Or If Then Had Has Have Was Were Are Is It Its
    This That These Those There Here When Where Who Whom Whose What
    Which While With From For On In At To Of By As Every Everywhere
    Had Means SatNav
  ].freeze

  REQUEST_KEYS = %w[
    operationId idempotencyKey idempotencyScope callerIri journal_ref
  ].freeze

  module_function

  # Wire entry: journal_ref names the completed memory.land (its
  # operationId). Reads the land receipt, the blob, and the Bronze
  # provenance, then conforms.
  def call(params, graph_client: nil, blob: nil)
    p = stringify(params)
    opid = p["operationId"].to_s
    if opid.empty?
      raise refusal("operation_id_required", { "detail" => "memory.conform names its effect first" })
    end
    journal_ref = p["journal_ref"].to_s
    if journal_ref.empty?
      raise refusal("audit_rejected", { "detail" => "memory.conform needs journal_ref: the completed memory.land it conforms" })
    end

    land = RailsOsiLevel8::OperationRequest.admitted
             .find_by(operation_name: "memory.land", idempotency_key: journal_ref)
    if land.nil? || land.receipt.nil?
      raise refusal("episode_not_landed", {
                      "detail" => "no completed memory.land for journal_ref #{journal_ref.inspect}; " \
                                  "conform follows land, it does not invent episodes",
                      "journal_ref" => journal_ref
                    })
    end

    client = graph_client || Mmg::Graph::Execute
    blob_ops = blob || Mmg::Blob::Operations

    # The handoff is the Bronze graph, not the land receipt: the receipt
    # links a context cid nothing ever stores, while the graph carries
    # the journalRef triple S1 wrote. One lookup finds the episode, a
    # second reads it whole.
    episode_iri = bronze_episode_for(client, journal_ref)
    if episode_iri.nil?
      raise refusal("episode_not_landed", {
                      "detail" => "journal_ref #{journal_ref.inspect} names no Bronze episode; " \
                                  "nothing to conform",
                      "journal_ref" => journal_ref
                    })
    end

    triples = bronze_triples(client, episode_iri)
    cols = {}
    triples.each { |row| cols[row["p"]] = row["o"] }
    digest = cols["mm:blob"] || cols["<mm:blob>"]
    if digest.to_s.empty?
      raise refusal("episode_not_landed", {
                      "detail" => "Bronze episode #{episode_iri} names no blob; nothing to conform",
                      "episode_iri" => episode_iri
                    })
    end
    blob_got = blob_ops.get("digest" => digest)
    unless blob_got.is_a?(Hash) && blob_got[:ok]
      raise refusal("blob_unavailable", {
                      "detail" => "episode blob #{digest} unreadable: #{blob_got.inspect[0, 160]}",
                      "digest" => digest.to_s
                    })
    end
    text = Base64.strict_decode64(blob_got[:bytes].to_s)
    provenance = bronze_cols(cols)

    result = conform_episode(
      episode_iri: episode_iri, text: text, provenance: provenance,
      graph_client: graph_client
    )
    result.merge("journal_ref" => journal_ref)
  end

  # Graph core. Returns episode_iri, entities, facts_written, closed,
  # skipped, shacl report, silver_graph. Never-raise is the caller's job
  # (KnownRefusal); invalid states here raise it directly.
  def conform_episode(episode_iri:, text:, provenance:, graph_client: nil)
    client = graph_client || Mmg::Graph::Execute
    observed_at = provenance["observed_at"].to_s
    if observed_at.empty?
      raise refusal("audit_rejected", { "detail" => "conform needs the episode observed_at for valid_from" })
    end

    claims = extract_claims(text.to_s)
    labels_index, facts = load_silver(client)

    entities = []
    new_lines = []
    new_facts = 0
    closes = []
    skipped = 0
    claims.each do |claim|
      iri = resolve(client, labels_index, claim[:surface])
      entities |= [iri]
      fact_iri = fact_iri_for(episode_iri, iri, claim[:predicate], claim[:object])

      live = facts.select do |f|
        f[:subject] == iri && f[:predicate] == claim[:predicate] && f[:valid_to].nil?
      end
      if live.any? { |f| f[:object] == claim[:object] && f[:fact] != fact_iri } ||
         facts.any? { |f| f[:fact] == fact_iri }
        # Same claim already Silver (possibly from an earlier conform of
        # this same episode): idempotent skip. A duplicate conform writes
        # nothing, which is what makes retry safe.
        skipped += 1
        next
      end
      live.each do |f|
        closes << { fact: f[:fact], valid_to: observed_at }
      end
      new_lines.concat(fact_lines(
        fact_iri: fact_iri, subject: iri, predicate: claim[:predicate],
        object: claim[:object], valid_from: observed_at, episode_iri: episode_iri
      ))
      new_facts += 1
      # Labels are direct index triples (subject -> surface), each with a
      # source companion so the batch keeps its sourceEpisode requirement.
      # Surfaces already indexed for this iri (graph or earlier this run)
      # are not re-emitted.
      known_surfaces = labels_index.select { |_, v| v[:iri] == iri }
                                   .values.flat_map { |v| v[:surfaces] }
      claim[:label_lines].uniq.each do |surface|
        next if known_surfaces.include?(surface)

        new_lines << "<#{iri}> <mm:label> \"#{nt_escape(surface)}\" ."
        new_lines << "<#{iri}> <mm:sourceEpisode> <#{episode_iri}> ."
        known_surfaces << surface
      end
      labels_index = note_surface(labels_index, iri, claim[:surface])
    end

    gate = if new_lines.empty?
             # Vacuous conform: nothing new to check. Skipping the gate
             # is not skipping validation -- there is no batch.
             { ok: true, engine: Mmg::Medallion::ShapeSet::ENGINE, violations: [] }
           else
             silver_shape_set.validate(new_lines)
           end
    unless gate[:ok]
      raise refusal("shacl_failed", {
                      "detail" => "#{gate[:violations].size} SHACL violation(s): " \
                                  "#{gate[:violations].first(3).join('; ')}",
                      "violations" => gate[:violations]
                    })
    end

    unless new_lines.empty?
      written = client.update(insert_data(SILVER_GRAPH, new_lines))
      unless written.is_a?(Hash) && written[:ok]
        raise refusal("graph_write_failed", {
                        "detail" => "Silver INSERT failed: #{written.inspect[0, 200]}",
                        "graph" => SILVER_GRAPH
                      })
      end
    end
    closes.each do |c|
      close_updates(c[:fact], c[:valid_to]).each do |sparql|
        closed = client.update(sparql)
        unless closed.is_a?(Hash) && closed[:ok]
          raise refusal("graph_write_failed", {
                          "detail" => "Silver close of #{c[:fact]} failed: #{closed.inspect[0, 200]}",
                          "graph" => SILVER_GRAPH
                        })
        end
      end
    end

    {
      "episode_iri" => episode_iri,
      "entities" => entities,
      "facts_written" => new_facts,
      "closed" => closes.size,
      "skipped" => skipped,
      "shacl_engine" => gate[:engine],
      "shacl_violations" => gate[:violations],
      "silver_graph" => SILVER_GRAPH
    }
  end

  # --- extraction (deterministic v1) ---

  def extract_claims(text)
    claims = []
    # Initials end in periods but not in sentences: protect them before
    # splitting, or "P. Raman" becomes the sentence "P." plus a mention
    # ("Raman") that resolves to a different normalized key.
    sentences = text.to_s.gsub(/\b([A-Z])\.\s+/, '\1<DOT> ').split(/(?<=[.!?])\s+/)
    sentences.map! { |s| s.gsub("<DOT>", ".") }
    sentences.each do |sentence|
      sentence.scan(MENTION).flatten.map(&:strip).each do |surface|
        tokens = surface.split(/\s+/)
        tokens.shift while tokens.size > 1 && STOPWORDS.include?(tokens.first)
        next if tokens.empty?
        next if tokens.size == 1 && STOPWORDS.include?(tokens.first)

        clean = tokens.join(" ")
        m = sentence.match(/#{Regexp.escape(clean)}\s+is\s+(?:now\s+)?(?:my\s+|a\s+|the\s+)?([^.,!?;]+)/i)
        next unless m

        claims << {
          surface: clean, predicate: "mm:role", object: m[1].strip.downcase,
          label_lines: [clean]
        }
      end
    end
    claims
  end

  def normalize(label)
    label.to_s.downcase.gsub(".", "").squeeze(" ").strip
  end

  def tokens_of(normalized)
    normalized.split(" ")
  end

  def surfaces_match?(a_norm, b_norm)
    return true if a_norm == b_norm

    a, b = tokens_of(a_norm), tokens_of(b_norm)
    return false if a.empty? || b.empty?
    return false unless a.last == b.last

    fa, fb = a.first, b.first
    fa == fb || (fa.size == 1 && fb.start_with?(fa)) || (fb.size == 1 && fa.start_with?(fb))
  end

  def mint_iri(normalized)
    slug = normalized.tr(" ", "-")
    short = Digest::SHA256.hexdigest(normalized)[0, 8]
    "urn:mm:entity:#{slug}-#{short}"
  end

  def fact_iri_for(episode_iri, subject, predicate, object)
    "urn:mm:fact:#{Digest::SHA256.hexdigest([episode_iri, subject, predicate, object].join("\0"))[0, 12]}"
  end

  # --- silver I/O (two query shapes; markers keep fakes honest) ---

  def load_silver(client)
    labels = {}
    facts = []

    lab = client.query(select_labels)
    unless lab.is_a?(Hash) && lab[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Silver label read failed: #{lab.inspect[0, 200]}",
                      "graph" => SILVER_GRAPH
                    })
    end
    Array(lab[:rows]).each do |row|
      r = stringify(row)
      norm = normalize(r["o"].to_s)
      labels[norm] ||= { iri: r["s"].to_s, surfaces: [] }
      labels[norm][:surfaces] |= [r["o"].to_s]
    end

    all = client.query(select_facts)
    unless all.is_a?(Hash) && all[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Silver fact read failed: #{all.inspect[0, 200]}",
                      "graph" => SILVER_GRAPH
                    })
    end
    by_fact = {}
    Array(all[:rows]).each do |row|
      r = stringify(row)
      (by_fact[r["f"]] ||= {})[r["p"]] = r["o"]
    end
    by_fact.each do |fact_iri, cols|
      next if cols["mm:subject"].nil?

      facts << {
        fact: fact_iri, subject: cols["mm:subject"], predicate: cols["mm:predicate"],
        object: cols["mm:object"], valid_from: cols["mm:validFrom"], valid_to: cols["mm:validTo"]
      }
    end

    [labels, facts]
  end
  private_class_method :load_silver

  def resolve(_client, labels_index, surface)
    norm = normalize(surface)
    hit = labels_index.keys.find { |k| surfaces_match?(k, norm) }
    return labels_index[hit][:iri] if hit

    mint_iri(norm)
  end
  private_class_method :resolve

  def note_surface(labels_index, iri, surface)
    norm = normalize(surface)
    labels_index[norm] ||= { iri: iri, surfaces: [] }
    labels_index[norm][:surfaces] |= [surface]
    labels_index
  end
  private_class_method :note_surface

  def select_labels
    "# s2:labels\nSELECT ?s ?o WHERE { GRAPH <#{SILVER_GRAPH}> { ?s <mm:label> ?o } }"
  end
  private_class_method :select_labels

  def select_facts
    "# s2:facts\nSELECT ?f ?p ?o WHERE { GRAPH <#{SILVER_GRAPH}> { ?f ?p ?o } }"
  end
  private_class_method :select_facts

  def insert_data(graph, lines)
    "INSERT DATA { GRAPH <#{graph}> {\n#{Array(lines).join("\n")}\n} }"
  end
  private_class_method :insert_data

  # A close is two updates, not one: DELETE/INSERT with an unbound
  # DELETE variable is a silent no-op on oxigraph (the INSERT never
  # lands either), so the delete is a DELETE WHERE that only matches a
  # present validTo, followed by a plain INSERT DATA.
  def close_updates(fact_iri, valid_to)
    [
      "# s2:close\nDELETE WHERE { GRAPH <#{SILVER_GRAPH}> { <#{fact_iri}> <mm:validTo> ?v } }",
      "# s2:close\nINSERT DATA { GRAPH <#{SILVER_GRAPH}> { <#{fact_iri}> <mm:validTo> \"#{valid_to}\" } }"
    ]
  end
  private_class_method :close_updates

  def fact_lines(fact_iri:, subject:, predicate:, object:, valid_from:, episode_iri:)
    [
      "<#{fact_iri}> <mm:subject> <#{subject}> .",
      "<#{fact_iri}> <mm:predicate> <#{predicate}> .",
      "<#{fact_iri}> <mm:object> \"#{nt_escape(object)}\" .",
      "<#{fact_iri}> <mm:validFrom> \"#{nt_escape(valid_from)}\" .",
      "<#{fact_iri}> <mm:sourceEpisode> <#{episode_iri}> ."
    ]
  end
  private_class_method :fact_lines

  def nt_escape(value)
    value.to_s.gsub("\\", "\\\\").gsub('"', '\\"')
  end
  private_class_method :nt_escape

  def silver_shape_set
    Mmg::Medallion::ShapeSet.register(
      "silver:v1",
      allow_predicates: %w[mm:subject mm:predicate mm:object mm:validFrom mm:validTo mm:sourceEpisode mm:label],
      required_predicates: ["mm:sourceEpisode"]
    )
  end
  private_class_method :silver_shape_set

  # --- wire-only lookups ---

  def bronze_episode_for(client, journal_ref)
    res = client.query(
      "# s2:episode\nSELECT ?s WHERE { GRAPH <#{BRONZE_GRAPH}> { " \
      "?s <mm:journalRef> \"#{nt_escape(journal_ref)}\" } }"
    )
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Bronze episode lookup failed: #{res.inspect[0, 200]}",
                      "journal_ref" => journal_ref
                    })
    end
    row = Array(res[:rows]).first
    row && stringify(row)["s"]
  end
  private_class_method :bronze_episode_for

  def bronze_triples(client, episode_iri)
    res = client.query(
      "# s2:bronze\nSELECT ?p ?o WHERE { GRAPH <#{BRONZE_GRAPH}> { <#{episode_iri}> ?p ?o } }"
    )
    unless res.is_a?(Hash) && res[:ok]
      raise refusal("graph_read_failed", {
                      "detail" => "Bronze read for #{episode_iri} failed: #{res.inspect[0, 200]}",
                      "episode_iri" => episode_iri
                    })
    end
    Array(res[:rows]).map { |row| stringify(row) }
  end
  private_class_method :bronze_triples

  # Bronze predicates are short <mm:*> names (S1). Accept both the short
  # and angle-bracketed spellings; the graph returns full terms.
  def bronze_cols(cols)
    pick = lambda do |short|
      cols[short] || cols["<#{short}>"]
    end
    {
      "session" => pick.call("mm:session"),
      "actor" => pick.call("mm:actor"),
      "observed_at" => pick.call("mm:observedAt"),
      "modality" => pick.call("mm:modality"),
      "source_system" => pick.call("mm:sourceSystem"),
      "kind" => pick.call("mm:kind")
    }
  end
  private_class_method :bronze_cols

  # Runtime twin for Memory::ConformEffectShape.
  def request_violations(graph)
    g = stringify(graph || {})
    v = []
    (g.keys - REQUEST_KEYS - %w[@id]).each do |k|
      v << { path: k, message: "undeclared property #{k} is refused by a closed shape" }
    end
    v << { path: "journal_ref", message: "memory.conform needs journal_ref" } if blank?(g["journal_ref"])
    v
  end

  # Runtime twin for Memory::ConformContextShape.
  def response_violations(graph)
    g = stringify(graph || {})
    items = g["items"]
    item = items.is_a?(Array) && items.length == 1 && items.first.is_a?(Hash) ? items.first : nil
    v = []
    v << { path: "items", message: "a conform response carries exactly one episode" } if item.nil?
    if item
      v << { path: "episode_iri", message: "conform must report the episode it conformed" } if blank?(item["episode_iri"])
      v << { path: "silver_graph", message: "conform must report the graph it wrote" } if blank?(item["silver_graph"])
      unless item["entities"].is_a?(Array)
        v << { path: "entities", message: "conform must report resolved entities as a list" }
      end
      fw = item["facts_written"]
      v << { path: "facts_written", message: "conform must report its fact count" } unless fw.is_a?(Integer) && fw >= 0
    end
    v
  end

  def refusal(reason, because)
    RailsOsiLevel8::KnownRefusal.new(reason, because)
  end
  private_class_method :refusal

  def blank?(value)
    value.nil? || (value.respond_to?(:empty?) && value.empty?)
  end
  private_class_method :blank?

  def stringify(obj)
    case obj
    when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
    when Array then obj.map { |v| stringify(v) }
    else obj
    end
  end
  private_class_method :stringify
end
