# frozen_string_literal: true

require "digest"
require "pathname"

module Vv
  module PerSite
    module Okf
      # Walk an OKF docs/ folder and emit a flat list of node hashes in
      # parent-before-child order. Pure: does not touch AR.
      module Tree
        SKIP_NAMES = %w[. .. .git .DS_Store].freeze

        module_function

        def walk(docs_root, bundle_key: nil)
          root = Pathname.new(docs_root).expand_path
          return { ok: false, reason: :docs_missing, because: root.to_s } unless root.directory?

          index_path = root.join("index.md")
          index_text = index_path.file? ? index_path.read(encoding: "UTF-8") : ""
          parsed = Parser.parse(index_text)
          key = bundle_key.to_s
          key = inferred_bundle_key(parsed, root) if key.empty?

          nodes = []
          nodes << document_node(
            parsed,
            okf_path: "index.md",
            parent_okf_path: nil,
            kind: "bundle",
            source_path: "index.md",
            position: 0,
            digest: digest_of(index_text),
            bundle_key: key,
            fallback_title: root.basename.to_s
          )

          children = entries(root).reject { |p| p.basename.to_s == "index.md" }
          children.each_with_index do |entry, i|
            walk_entry(entry, root, key, "index.md", i, nodes)
          end

          { ok: true, bundle_key: key, nodes: nodes, docs_root: root.to_s }
        end

        def walk_entry(entry, root, bundle_key, parent_okf_path, position, nodes)
          rel = entry.relative_path_from(root).to_s
          if entry.directory?
            nodes << folder_node(entry, rel, parent_okf_path, position, bundle_key)
            entries(entry).each_with_index do |child, i|
              walk_entry(child, root, bundle_key, rel, i, nodes)
            end
          elsif markdown?(entry)
            text = entry.read(encoding: "UTF-8")
            parsed = Parser.parse(text)
            kind = Parser.cta_leaf?(parsed[:body], parsed[:frontmatter]) && Parser.sections(parsed[:body]).empty? ? "cta_leaf" : "document"
            nodes << document_node(
              parsed,
              okf_path: rel,
              parent_okf_path: parent_okf_path,
              kind: kind,
              source_path: rel,
              position: position,
              digest: digest_of(text),
              bundle_key: bundle_key,
              fallback_title: entry.basename(".md").to_s
            )
            append_sections(nodes, parsed, rel, bundle_key)
          end
        end

        def append_sections(nodes, parsed, doc_path, bundle_key)
          stack = [{ level: 1, path: doc_path }]
          Parser.sections(parsed[:body]).each do |section|
            stack.pop while stack.length > 1 && stack.last[:level] >= section[:level]
            parent_okf_path = stack.last[:path]
            okf_path = "#{doc_path}##{section[:slug]}"
            nodes << {
              "bundle_key" => bundle_key,
              "okf_path" => okf_path,
              "parent_okf_path" => parent_okf_path,
              "kind" => section[:cta_leaf] ? "cta_leaf" : "section",
              "doc_type" => "Section",
              "title" => section[:title],
              "description" => nil,
              "slug" => section[:slug],
              "status" => parsed[:status],
              "okf_version" => parsed[:okf_version],
              "position" => section[:position],
              "generated_by" => parsed[:generated_by],
              "generated_at" => parsed[:generated_at],
              "digest" => digest_of(section[:body].to_s),
              "source_path" => doc_path,
              "tags" => parsed[:tags],
              "sources" => parsed[:sources],
              "frontmatter" => {},
              "body" => section[:body]
            }
            stack << { level: section[:level], path: okf_path }
          end
        end

        def document_node(parsed, okf_path:, parent_okf_path:, kind:, source_path:, position:, digest:, bundle_key:, fallback_title:)
          title = parsed[:title]
          title = fallback_title if title.to_s.empty?
          {
            "bundle_key" => bundle_key,
            "okf_path" => okf_path,
            "parent_okf_path" => parent_okf_path,
            "kind" => kind,
            "doc_type" => parsed[:doc_type].to_s.empty? ? kind.capitalize : parsed[:doc_type],
            "title" => title,
            "description" => parsed[:description],
            "slug" => Parser.slug_for(title),
            "status" => parsed[:status],
            "okf_version" => parsed[:okf_version],
            "position" => position,
            "generated_by" => parsed[:generated_by],
            "generated_at" => parsed[:generated_at],
            "digest" => digest,
            "source_path" => source_path,
            "tags" => parsed[:tags],
            "sources" => parsed[:sources],
            "frontmatter" => parsed[:frontmatter],
            "body" => parsed[:body]
          }
        end

        def folder_node(entry, rel, parent_okf_path, position, bundle_key)
          title = rel.split("/").last
          {
            "bundle_key" => bundle_key,
            "okf_path" => rel,
            "parent_okf_path" => parent_okf_path,
            "kind" => "folder",
            "doc_type" => "Folder",
            "title" => title,
            "description" => nil,
            "slug" => Parser.slug_for(rel.split("/").last),
            "status" => nil,
            "okf_version" => nil,
            "position" => position,
            "generated_by" => nil,
            "generated_at" => nil,
            "digest" => nil,
            "source_path" => rel,
            "tags" => [],
            "sources" => [],
            "frontmatter" => {},
            "body" => nil
          }
        end

        def entries(dir)
          dir.children
             .reject { |p| SKIP_NAMES.include?(p.basename.to_s) || p.basename.to_s.start_with?(".") }
             .select { |p| p.directory? || markdown?(p) }
             .sort_by { |p| [p.directory? ? 0 : 1, p.basename.to_s.downcase] }
        end

        def markdown?(path)
          path.file? && path.extname.downcase == ".md"
        end

        def digest_of(text)
          Digest::SHA256.hexdigest(text.to_s)
        end

        def inferred_bundle_key(parsed, root)
          slug = Parser.slug_for(parsed[:title])
          return slug unless slug.empty?

          Parser.slug_for(root.basename.to_s)
        end
      end
    end
  end
end
