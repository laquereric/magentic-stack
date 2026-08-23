# frozen_string_literal: true

require_relative "semantic_editor/version"
require_relative "semantic_editor/disclosure"
require_relative "semantic_editor/canonical_id"
require_relative "semantic_editor/document"
require_relative "semantic_editor/prose"
require_relative "semantic_editor/decompose"

module Mmg
  # A SEMANTIC EDITOR.
  #
  # Ordinary editors edit a document. This one edits a document that STANDS FOR
  # several records, and knows which is which. That single difference is what
  # lets a person write a paragraph about a Frame and have it land as edits to
  # the frame, its meanings and their clarifications at once -- without the
  # person holding the record boundaries in their head.
  #
  # It exists because of what the board is for. A Frame is the apparatus a
  # person reasons WITHIN; adjusting it is the act of agency the board is built
  # to support. That act should feel like writing, not like filling in a form.
  #
  # The gem is deliberately headless. It knows about ACIA trees, canonical ids,
  # disclosure tiers and prose; it knows nothing about the board, HTTP, or any
  # particular store. The board mounts it as a modal; a different consumer could
  # mount it anywhere.
  #
  #   session = Mmg::SemanticEditor.open(acia: tree, focus: "Y1")
  #   session[:prose]                        # => editable text
  #   plan = Mmg::SemanticEditor.stage(session: session, acia: edited_tree)
  #   Mmg::SemanticEditor.commit(plan) { |target, edits| store.write(target, edits) }
  module SemanticEditor
    module_function

    # Open an edit session over an ACIA tree.
    #
    # `focus` names the canonical id the session is ABOUT. It is not a filter --
    # the whole tree stays available -- but it decides what prose mode renders
    # and which frame boundary cross-frame edits are measured against.
    def open(acia:, focus: nil, tier: Disclosure::DEFAULT)
      adm = Document.admissible?(acia)
      return adm unless adm[:ok]

      idx = Document.index(acia)
      visible = Document.at_tier(acia, tier)
      return visible unless visible[:ok]

      focus_id = focus&.to_s
      if focus_id && !idx[:entries].key?(focus_id)
        return { ok: false, reason: :unknown_focus,
                 because: "#{focus_id} is not a node in this document" }
      end

      session = { ok: true,
                  focus: focus_id,
                  tier: visible[:tier],
                  entries: idx[:entries],
                  visible: visible[:entries].keys,
                  editable: idx[:editable],
                  derived: idx[:derived] }

      if focus_id
        session[:hidden] = Document.hidden_beneath(acia, focus_id, tier)[:hidden] || []
        prose = prose_for(idx[:entries], focus_id)
        session[:prose] = prose[:ok] ? prose[:text] : nil
        session[:prose_refusal] = prose[:ok] ? nil : { reason: prose[:reason], because: prose[:because] }
      end

      session
    end

    # Turn an edited tree into the set of writes it implies. Nothing is written.
    def stage(session:, acia:)
      return { ok: false, reason: :no_session, because: "expected an open session" } unless session.is_a?(Hash) && session[:entries]

      Decompose.plan(before: { ok: true, entries: session[:entries] }, after: acia)
    end

    # Apply a staged plan, whole or not at all.
    def commit(plan, &writer)
      Decompose.apply(plan, &writer)
    end

    # Prose mode over an already-indexed document, assembled from the entries
    # rather than from a caller-supplied Hash, so the ids in the text are the
    # ids that are actually in the document.
    def prose_for(entries, frame_id)
      parsed = CanonicalId.parse(frame_id)
      return parsed unless parsed[:ok]
      unless parsed[:kind] == :frame
        return { ok: false, reason: :prose_needs_a_frame,
                 because: "prose mode renders a frame and what it carries; #{frame_id} is a #{parsed[:kind]}" }
      end

      frame = record(entries, frame_id)
      meanings = entries.keys.select { |k| CanonicalId.parse(k)[:kind] == :meaning && k.start_with?("#{frame_id}:") }.sort

      frame[:meanings] = meanings.map do |mid|
        m = record(entries, mid)
        clar = entries.keys.select { |k| CanonicalId.parse(k)[:kind] == :clarification && k.start_with?("#{mid}:") }.sort
        m[:clarifications] = clar.map { |cid| record(entries, cid) }
        m
      end

      Prose.render(frame)
    end

    def record(entries, cid)
      props = entries.dig(cid, :props) || {}
      value = props["valueJson"] || {}
      { id: cid,
        label: props["label"] || value["label"] || props["title"] || "",
        body: props["body"] || value["body"] || "" }
    end
    private_class_method :record
  end
end
