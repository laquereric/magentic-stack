# frozen_string_literal: true

module Mmg
  module Acia
    # Composes the Profile 2 +p2:previewText+ for a node.
    #
    # A preview answers two questions for a model that has not dereferenced the
    # node: what is this, and what may be done with it. The second question is
    # the affordance -- the same idea Profile 9 renders as a glyph on a card
    # (+ add, - remove, ? explore, ! trace). Here there is no glyph, so the
    # affordance is named.
    #
    # Every clause is composed from a column. Nothing is inferred about status,
    # outcome or intent: a preview a model trusts must not carry a guess, and an
    # invented clause is worse than a missing one because it reads as a fact.
    #
    # Pure: takes values, returns a String. The query that finds a tree's
    # affordances lives in the caller.
    module PreviewComposer
      module_function

      NOUNS = {
        "friction" => "friction record",
        "arc" => "arc",
        "brief" => "brief",
        "repo" => "repository",
        "mcb_action" => "affordance"
      }.freeze

      # Effects we can describe because the action registry describes them.
      # An action absent here is named but not characterized -- see .action_text.
      DESCRIBED_ACTIONS = {
        "arc_flow_run_show" =>
          "reads an arc-flow run and its captured SUPER<->SLOT conversation; read-only"
      }.freeze

      # @param kind [String] "action" or "entity_token"
      # @param semantic_role [String] domain role -- friction, arc, brief, repo, mcb_action
      # @param entity_iri [String] the urn: this node stands for
      # @param value [String] the node's label
      # @param tree_key [String] the pane the node appears on
      # @param affords [Array<String>] labels of the action nodes on the same tree
      # @return [String, nil] nil when there is nothing truthful to say
      def compose(kind:, semantic_role:, entity_iri:, value:, tree_key:, affords: [])
        return nil if entity_iri.to_s.empty?

        if kind.to_s == "action"
          action_text(value: value, entity_iri: entity_iri, tree_key: tree_key)
        else
          entity_text(semantic_role: semantic_role, entity_iri: entity_iri,
                      value: value, tree_key: tree_key, affords: affords)
        end
      end

      # The identifier without its urn: scheme -- what a human would call it.
      def local_name(entity_iri)
        entity_iri.to_s.sub(/\Aurn:mm:[a-z_]+:/, "")
      end

      def noun_for(semantic_role)
        NOUNS.fetch(semantic_role.to_s, semantic_role.to_s)
      end

      def action_text(value:, entity_iri:, tree_key:)
        action = local_name(entity_iri)
        text = %(The "#{value}" affordance on the #{tree_key} pane; ) \
               "it invokes the MCB action #{action}"
        described = DESCRIBED_ACTIONS[action]
        return "#{text}, which #{described}." if described

        # Naming an effect the registry does not describe would be the guess
        # this module exists to avoid.
        "#{text}. Its effect is not described in the action registry."
      end

      def entity_text(semantic_role:, entity_iri:, value:, tree_key:, affords:)
        text = +"The #{noun_for(semantic_role)} #{local_name(entity_iri)}, " \
                "shown on the #{tree_key} pane"
        # A repo's label carries live state the IRI does not.
        text << " (#{value})" if semantic_role.to_s == "repo" && !value.to_s.empty?
        text << ". Dereference #{entity_iri} for the record itself"
        offered = Array(affords).map(&:to_s).reject(&:empty?).uniq
        text << (offered.empty? ? "." : "; the pane affords #{offered.join(', ')}.")
        text
      end
    end
  end
end
