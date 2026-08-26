# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    module ComponentMin
      # Closed SAL-17 catalog (aligned with Mmg::Site::DesignMd::SAL_KINDS).
      module SalCatalog
        module_function

        KINDS = %w[
          surface pane link header footer list item table row cell
          semantic_text details modal text entity_token action enqueue
        ].freeze

        # HTML tag / class heuristics → SAL kind (best-effort).
        TAG_MAP = {
          "html" => "surface", "body" => "surface",
          "header" => "header", "footer" => "footer", "nav" => "list",
          "main" => "pane", "section" => "pane", "article" => "pane", "aside" => "pane",
          "div" => "pane", "ul" => "list", "ol" => "list", "li" => "item",
          "table" => "table", "tr" => "row", "td" => "cell", "th" => "cell",
          "a" => "link", "button" => "action", "form" => "enqueue",
          "input" => "action", "textarea" => "action",
          "h1" => "text", "h2" => "text", "h3" => "text", "h4" => "text",
          "p" => "semantic_text", "span" => "text", "img" => "entity_token",
          "details" => "details", "dialog" => "modal", "summary" => "text"
        }.freeze

        CLASS_HINTS = {
          /hero|banner/i => "pane",
          /nav|menu/i => "list",
          /card|feature|item/i => "item",
          /btn|button|cta/i => "action",
          /modal|dialog/i => "modal",
          /footer/i => "footer",
          /header|navbar/i => "header"
        }.freeze

        def kinds
          if defined?(::Mmg::Site::DesignMd) && ::Mmg::Site::DesignMd.respond_to?(:catalog)
            ::Mmg::Site::DesignMd.catalog.map(&:to_s)
          elsif defined?(::Mmg::Sal::Shapes) && ::Mmg::Sal::Shapes.respond_to?(:kinds)
            ::Mmg::Sal::Shapes.kinds.map(&:to_s)
          else
            KINDS
          end
        end

        def map_tag(tag, class_name: nil)
          t = tag.to_s.downcase
          c = class_name.to_s
          CLASS_HINTS.each do |re, kind|
            return kind if c.match?(re)
          end
          TAG_MAP[t] || "pane"
        end

        def sal?(kind) = kinds.include?(kind.to_s)
      end
    end
  end
end
