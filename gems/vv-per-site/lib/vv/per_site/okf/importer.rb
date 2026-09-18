# frozen_string_literal: true

require "time"

module Vv
  module PerSite
    module Okf
      # Upsert a walked OKF tree into the ancestry AR table. Never raises.
      module Importer
        module_function

        def import(docs_root, bundle_key: nil)
          walked = Tree.walk(docs_root, bundle_key: bundle_key)
          return walked unless walked[:ok]

          load_nodes(walked[:nodes])
        rescue StandardError => e
          { ok: false, reason: :import_failed, because: "#{e.class}: #{e.message}" }
        end

        def load_nodes(nodes)
          return { ok: false, reason: :no_active_record, because: "ActiveRecord is not loaded" } unless defined?(::ActiveRecord::Base)
          return { ok: false, reason: :empty, because: "no nodes" } if nodes.nil? || nodes.empty?

          created = 0
          updated = 0
          by_path = {}

          ActiveRecord::Base.transaction do
            nodes.each do |attrs|
              row, was_new = upsert(attrs, by_path)
              by_path[row.okf_path] = row
              was_new ? created += 1 : updated += 1
            end
          end

          { ok: true, created: created, updated: updated, nodes: nodes.size,
            bundle_key: nodes.first["bundle_key"] || nodes.first[:bundle_key] }
        rescue StandardError => e
          { ok: false, reason: :import_failed, because: "#{e.class}: #{e.message}" }
        end

        def upsert(attrs, by_path)
          h = stringify(attrs)
          row = OkfNode.find_or_initialize_by(bundle_key: h["bundle_key"], okf_path: h["okf_path"])
          was_new = row.new_record?
          parent = h["parent_okf_path"] && by_path[h["parent_okf_path"]]
          row.parent = parent if parent
          row.assign_attributes(ar_attrs(h))
          row.save!
          [row, was_new]
        end

        def ar_attrs(h)
          {
            parent_okf_path: h["parent_okf_path"],
            kind: h["kind"],
            doc_type: h["doc_type"],
            title: h["title"],
            description: h["description"],
            slug: h["slug"],
            status: blank_to_nil(h["status"]),
            okf_version: blank_to_nil(h["okf_version"]),
            position: h["position"].to_i,
            generated_by: h["generated_by"],
            generated_at: parse_time(h["generated_at"]),
            digest: h["digest"],
            source_path: h["source_path"],
            tags: h["tags"] || [],
            sources: h["sources"] || [],
            frontmatter: h["frontmatter"] || {},
            body: h["body"]
          }
        end

        def stringify(attrs)
          attrs.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
        end

        def blank_to_nil(value)
          value.to_s.empty? ? nil : value.to_s
        end

        def parse_time(value)
          return value if value.is_a?(Time)
          return nil if value.nil? || value.to_s.empty?

          Time.iso8601(value.to_s)
        rescue ArgumentError
          begin
            Time.parse(value.to_s)
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
