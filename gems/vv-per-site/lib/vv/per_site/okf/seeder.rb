# frozen_string_literal: true

require "date"
require "fileutils"
require "pathname"
require "yaml"

module Vv
  module PerSite
    module Okf
      # Convert an OKF docs/ tree into data/seed/docs YAML, and load that
      # YAML back into AR the way Rails seeds a database.
      #
      # Layout (mirrors docs/, .md → .yml):
      #
      #   data/seed/docs/_manifest.yml     ordered paths, parent before child
      #   data/seed/docs/index.yml
      #   data/seed/docs/from_human/_folder.yml
      #   data/seed/docs/from_human/vision.yml
      #   data/seed/docs/generated/personas.yml
      #   data/seed/docs/generated/personas/_sections.yml
      #   db/seeds.rb                      Rails entry: Seeder.load!
      module Seeder
        module_function

        def export(docs_root, seed_root, bundle_key: nil)
          walked = Tree.walk(docs_root, bundle_key: bundle_key)
          return walked unless walked[:ok]

          dest = Pathname.new(seed_root).expand_path
          FileUtils.mkdir_p(dest)
          written = []

          walked[:nodes].each do |node|
            rel = seed_relpath(node)
            path = dest.join(rel)
            FileUtils.mkdir_p(path.dirname)
            path.write(emit_yaml(node), encoding: "UTF-8")
            written << rel
          end

          dest.join("_manifest.yml").write(emit_manifest(walked, written), encoding: "UTF-8")
          { ok: true, seed_root: dest.to_s, files: written.size + 1,
            bundle_key: walked[:bundle_key], nodes: walked[:nodes].size }
        rescue StandardError => e
          { ok: false, reason: :export_failed, because: "#{e.class}: #{e.message}" }
        end

        def load!(seed_root)
          dest = Pathname.new(seed_root).expand_path
          return { ok: false, reason: :seed_missing, because: dest.to_s } unless dest.directory?

          nodes = read_nodes(dest)
          return { ok: false, reason: :empty, because: dest.to_s } if nodes.empty?

          Importer.load_nodes(nodes)
        rescue StandardError => e
          { ok: false, reason: :load_failed, because: "#{e.class}: #{e.message}" }
        end

        def sync(docs_root, seed_root, bundle_key: nil)
          exported = export(docs_root, seed_root, bundle_key: bundle_key)
          return exported unless exported[:ok]

          loaded = load!(seed_root)
          return loaded unless loaded[:ok]

          { ok: true, exported: exported, loaded: loaded }
        end

        def seed_relpath(node)
          path = node["okf_path"].to_s
          kind = node["kind"].to_s
          if kind == "folder"
            File.join(path, "_folder.yml")
          elsif path.include?("#")
            file, slug = path.split("#", 2)
            base = file.sub(/\.md$/i, "")
            File.join(base, "#{slug}.yml")
          else
            path.sub(/\.md$/i, ".yml")
          end
        end

        def read_nodes(dest)
          manifest = dest.join("_manifest.yml")
          if manifest.file?
            doc = YAML.safe_load(manifest.read, permitted_classes: [Date, Time], aliases: true) || {}
            files = Array(doc["files"])
            return files.map { |rel| load_yaml(dest.join(rel)) }.compact unless files.empty?
          end

          dest.glob("**/*.yml").reject { |p| p.basename.to_s.start_with?("_") }
              .sort_by { |p| p.to_s.count("/") }
              .map { |p| load_yaml(p) }
              .compact
        end

        def load_yaml(path)
          return nil unless path.file?
          return nil if path.basename.to_s == "_manifest.yml"

          YAML.safe_load(path.read, permitted_classes: [Date, Time], aliases: true)
        end

        def emit_manifest(walked, written)
          payload = {
            "bundle_key" => walked[:bundle_key],
            "okf_version" => walked[:nodes].dig(0, "okf_version"),
            "nodes" => walked[:nodes].size,
            "files" => written
          }
          YAML.dump(payload)
        end

        def emit_yaml(node)
          YAML.dump(stringify_for_yaml(node))
        end

        def stringify_for_yaml(value)
          case value
          when Hash
            value.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_for_yaml(v) }
          when Array
            value.map { |v| stringify_for_yaml(v) }
          when Time
            value.iso8601
          when Date
            value.iso8601
          else
            value
          end
        end
      end
    end
  end
end
