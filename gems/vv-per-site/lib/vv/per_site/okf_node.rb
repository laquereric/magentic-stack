# frozen_string_literal: true

require "ancestry"
require "json"

module Vv
  module PerSite
    # One node in an OKF docs tree. Folders, documents, heading-sections, and
    # CTA leaves share this table; `ancestry` is the hierarchy. A particular
    # site binds `Cta` rows onto leaf nodes — that is the per-site data. The
    # tree itself is the shared knowledge that drives the anonymous-user
    # questions along the way.
    class OkfNode < Record
      has_ancestry orphan_strategy: :destroy

      self.table_name = "vv_per_site_okf_nodes"

      KINDS = %w[bundle folder document section question cta_leaf].freeze

      has_many :ctas, class_name: "Vv::PerSite::Cta", inverse_of: :okf_node,
                      dependent: :destroy

      validates :bundle_key, :okf_path, :kind, :title, presence: true
      validates :kind, inclusion: { in: KINDS }
      validates :okf_path, uniqueness: { scope: :bundle_key }

      scope :in_bundle, ->(key) { where(bundle_key: key) }
      scope :cta_leaves, -> { where(kind: "cta_leaf") }
      scope :documents, -> { where(kind: "document") }
      scope :folders, -> { where(kind: "folder") }

      def tags
        parse_json(self[:tags], [])
      end

      def tags=(value)
        self[:tags] = JSON.generate(Array(value))
      end

      def frontmatter
        parse_json(self[:frontmatter], {})
      end

      def frontmatter=(value)
        self[:frontmatter] = JSON.generate(value.is_a?(Hash) ? value : {})
      end

      def sources
        parse_json(self[:sources], [])
      end

      def sources=(value)
        self[:sources] = JSON.generate(Array(value))
      end

      def cta_leaf?
        kind == "cta_leaf" || (is_childless? && !%w[bundle folder].include?(kind))
      end

      def to_seed_attrs
        {
          "bundle_key" => bundle_key,
          "okf_path" => okf_path,
          "parent_okf_path" => parent&.okf_path,
          "kind" => kind,
          "doc_type" => doc_type,
          "title" => title,
          "description" => description,
          "slug" => slug,
          "status" => status,
          "okf_version" => okf_version,
          "position" => position,
          "generated_by" => generated_by,
          "generated_at" => generated_at&.iso8601,
          "digest" => digest,
          "source_path" => source_path,
          "tags" => tags,
          "sources" => sources,
          "frontmatter" => frontmatter,
          "body" => body
        }
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
