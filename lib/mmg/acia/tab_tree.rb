# frozen_string_literal: true

module Mmg
  module Acia
    # Fixture builders for Phase-B Tab/TabList vertical slice.
    module TabTree
      module_function

      # Build a valid tablist with exactly one selected tab.
      def sample(selected: "billing", labels: %w[billing usage settings])
        tabs = labels.map do |lab|
          {
            kind: "tab",
            value: lab.to_s.capitalize,
            semantic_role: "tab",
            entity_token: "urn:mm:acia:tab:#{lab}",
            entity_iri: "urn:mm:acia:tab:#{lab}",
            semantic_state: {
              "selected" => (lab.to_s == selected.to_s),
              "controls" => "urn:mm:acia:panel:#{lab}"
            },
            children: []
          }
        end
        {
          kind: "pane",
          value: "Settings",
          semantic_role: "pane",
          entity_token: "urn:mm:acia:pane:settings",
          children: [
            {
              kind: "tablist",
              value: "sections",
              semantic_role: "tablist",
              entity_token: "urn:mm:acia:tablist:settings",
              entity_iri: "urn:mm:acia:tablist:settings",
              semantic_state: {},
              children: tabs
            }
          ]
        }
      end

      # Invalid: zero selected tabs.
      def zero_selected(labels: %w[a b])
        t = sample(selected: "__none__", labels: labels)
        t[:children][0][:children].each { |tab| tab[:semantic_state]["selected"] = false }
        t
      end

      # Invalid: two selected tabs.
      def dual_selected(labels: %w[a b c])
        t = sample(selected: labels.first, labels: labels)
        t[:children][0][:children][1][:semantic_state]["selected"] = true
        t
      end
    end
  end
end
