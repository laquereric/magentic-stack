# frozen_string_literal: true

require "json"

module Vv
  module PerSite
    # A Call To Action registered by a particular site against an OKF leaf.
    # The leaf (a persona "needs next", an entry point, an explicit CTA
    # section) lives in the shared tree; this row is the site's concrete
    # action — book a call, open a form, download a packet, hit a URL.
    class Cta < Record
      self.table_name = "vv_per_site_ctas"

      ACTION_KINDS = %w[calendar form download url message custom].freeze

      belongs_to :site, class_name: "Vv::PerSite::Site", inverse_of: :ctas
      belongs_to :okf_node, class_name: "Vv::PerSite::OkfNode", inverse_of: :ctas

      validates :key, :title, :action_kind, presence: true
      validates :action_kind, inclusion: { in: ACTION_KINDS }
      validates :key, uniqueness: { scope: :site_id }
      validates :okf_node_id, uniqueness: { scope: :site_id }

      def payload
        parse_json(self[:payload], {})
      end

      def payload=(value)
        self[:payload] = JSON.generate(value.is_a?(Hash) ? value : {})
      end

      private

      def parse_json(raw, fallback)
        return fallback if raw.nil? || raw.to_s.empty?

        value = raw.is_a?(String) ? JSON.parse(raw) : raw
        value.nil? ? fallback : value
      rescue JSON::ParserError
        fallback
      end
    end
  end
end
