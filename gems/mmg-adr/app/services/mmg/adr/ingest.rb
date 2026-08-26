# frozen_string_literal: true

require "pathname"

module Mmg
  module Adr
    # Read the ADR directory, project each file into a row, and publish each
    # row's attributes into a GROUNDED named graph.
    #
    # Boundary, so it returns { ok: ... } and never raises -- a governance index
    # that takes the process down when one file is malformed is a governance
    # index nobody leaves switched on.
    module Ingest
      module_function

      GLOB = "[0-9]*.md"

      # `repo_root` is stated rather than derived by climbing out of the ADR
      # directory a fixed number of levels: that guess is right for docs/adr and
      # silently wrong anywhere else. Declared paths resolve against it.
      def call(dir:, repo_root: nil, publish: true)
        dir = File.expand_path(dir.to_s)
        return { ok: false, reason: :no_such_dir, because: "#{dir} is not a directory" } unless File.directory?(dir)

        repo_root = File.expand_path(repo_root || File.join(dir, "..", ".."))
        files = Dir.glob(File.join(dir, GLOB)).sort
        return { ok: true, ingested: 0, records: [], chain_breaks: [], dangling: [], failed: [] } if files.empty?

        results = files.map { |path| ingest_one(path, repo_root: repo_root, publish: publish) }
        ok, failed = results.partition { |r| r[:ok] }

        {
          ok: failed.empty?,
          ingested: ok.size,
          failed: failed,
          records: ok.map { |r| r[:adr_id] }.compact,
          # Reported, not raised. These are the two findings the ledger exists to
          # surface, and they are normal conditions, not errors.
          # Only records still IN FORCE. A superseded ADR is history: it has been
          # replaced, so a missing enforcement link on it is not actionable, and
          # reporting it would grow the finding list forever as the ledger does --
          # which is how a governance report becomes noise nobody reads.
          chain_breaks: ok.reject { |r| r[:superseded] }
                          .filter_map { |r| r[:chain_break] && { adr_id: r[:adr_id], missing: r[:chain_break] } },
          dangling: ok.reject { |r| Array(r[:dangling]).empty? }.map { |r| { adr_id: r[:adr_id], paths: r[:dangling] } }
        }
      end

      def ingest_one(path, repo_root:, publish: true)
        parsed = Document.parse(File.read(path), path: relative(path, repo_root))
        return parsed.merge(path: path) unless parsed[:ok]

        attrs = parsed[:attributes]
        adr_id = attrs["adr_id"]
        return { ok: false, reason: :no_adr_id, because: "#{path} declares no id and its name does not start with digits" } if adr_id.nil?

        exists = ->(p) { File.exist?(File.join(repo_root, p.to_s)) }
        record = upsert(attrs)
        return record unless record[:ok]

        result = {
          ok: true, adr_id: adr_id, record: record[:record], legacy: attrs["legacy"],
          superseded: attrs["status"] == Vocabulary::TERMINAL,
          chain_break: Chain.break_at(attrs), dangling: Chain.dangling(attrs, exists: exists)
        }
        publish ? result.merge(published: publish_triples(record[:record], attrs)) : result
      rescue StandardError => e
        { ok: false, reason: :ingest_error, because: "#{e.class}: #{e.message}", path: path }
      end

      # The row is a projection of the file, so re-reading an unchanged file must
      # be a no-op. Comparing body_digest is what makes that true -- and what
      # makes an edit to an ACCEPTED file surface as a refusal rather than a
      # silent overwrite of the ledger.
      def upsert(attrs)
        return { ok: false, reason: :no_active_record, because: "ActiveRecord is not loaded" } unless defined?(::ActiveRecord::Base)

        record = Record.find_or_initialize_by(adr_id: attrs["adr_id"])
        record.title         = attrs["title"]
        record.status        = attrs["status"] || "proposed"
        record.date          = attrs["date"]
        record.subject_kind  = attrs["subject_kind"]
        record.subject       = attrs["subject"]
        record.components    = attrs["components"]
        record.paths         = attrs["paths"]
        record.enforced_by   = attrs["enforced_by"]
        record.supersedes    = attrs["supersedes"]
        record.superseded_by = attrs["superseded_by"]
        record.source_path   = attrs["source_path"]
        record.body_digest   = attrs["body_digest"]
        record.legacy        = attrs["legacy"] ? 1 : 0

        return { ok: true, record: record, unchanged: true } unless record.changed?
        return { ok: true, record: record } if record.save

        { ok: false, reason: :invalid_record, because: record.errors.full_messages.join("; "), adr_id: attrs["adr_id"] }
      end

      # Grounded by construction: attributes go into the named graph OF a
      # Mmg::Graph::Entry row. Execute.publish refuses a bare graph name, so
      # there is no path here that writes an anonymous node.
      def publish_triples(record, attrs)
        return { ok: false, reason: :graph_unavailable, because: "mmg-graph is not loaded" } unless defined?(::Mmg::Graph::Execute)

        entry = entry_for(record, attrs)
        return entry unless entry[:ok]

        # Replace rather than append: the row is a projection, and a projection
        # that accumulates every past version of itself stops being one.
        ::Mmg::Graph::Execute.update("DROP SILENT GRAPH <#{entry[:entry].graph_name}>")
        ::Mmg::Graph::Execute.publish(Projection.triples(attrs), entry: entry[:entry])
      end

      def entry_for(record, attrs)
        existing = record.graph_entry
        return { ok: true, entry: existing } if existing

        entry = ::Mmg::Graph::Entry.new(
          date: attrs["date"] || Time.now.utc.strftime("%Y-%m-%d"),
          name: "ADR #{attrs['adr_id']} -- #{attrs['title']}",
          description: "Attributes of architecture decision record #{attrs['adr_id']} " \
                       "(#{attrs['status']}), projected from #{attrs['source_path']}."
        )
        return { ok: false, reason: :entry_invalid, because: entry.errors.full_messages.join("; ") } unless entry.save

        record.update(graph_entry_id: entry.id)
        { ok: true, entry: entry }
      end

      def relative(path, root)
        Pathname(path).relative_path_from(Pathname(File.expand_path(root))).to_s
      rescue ArgumentError
        path.to_s
      end
    end
  end
end
