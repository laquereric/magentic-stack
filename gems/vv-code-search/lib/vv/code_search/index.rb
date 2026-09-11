# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module Vv
  module CodeSearch
    # The expensive half, done once per (repo, fork, rev, schema).
    #
    # plan_vv-code-search splits cost the same way SparqlFun.md does: index is
    # expensive and rare, lookup is cheap and constant. The split only pays if
    # the two never blur, so nothing in Lookup writes and nothing here runs on
    # the hot path.
    #
    # CONTENT ADDRESSING is by IDENTITY, not by content. The digest covers
    # (repo, fork, rev, schema_id) because that tuple is what a caller has in
    # hand when it wants to know whether an index exists -- an editor hovering a
    # line knows its checkout, not the hash of an index it has not built. Two
    # schemas over the same rev therefore land on different digests and cannot
    # merge, which is exactly the gate the doc asks for.
    class Index
      MANIFEST = "manifest.json"
      FORMAT = 1

      attr_reader :digest, :repo, :fork_name, :rev, :schema, :postings, :coverage, :built_dimensions

      def initialize(digest:, repo:, fork_name:, rev:, schema:, postings:, coverage:, built_dimensions:)
        @digest = digest
        @repo = repo
        @fork_name = fork_name
        @rev = rev
        @schema = schema
        @postings = postings
        @coverage = coverage
        @built_dimensions = built_dimensions
      end

      def self.digest_for(repo:, fork:, rev:, schema_id:)
        Digest::SHA256.hexdigest([repo, fork, rev, schema_id].join("\n"))
      end

      class << self
        # Builds every dimension the schema names and writes them under the
        # store. Returns an envelope; the index rides in :index.
        def build(repo:, rev:, schema:, root:, store:, fork: "origin")
          Envelope.never_raise do
            schema = Schema.named(schema) if schema.is_a?(String)
            return Envelope.refuse("schema_unknown", "no schema registered; known: #{Schema.ids.join(', ')}") if schema.nil?

            digest = digest_for(repo: repo, fork: fork, rev: rev, schema_id: schema.id)
            dir = File.join(store, digest)

            # A digest collision across DIFFERENT identities would mean two trees
            # sharing one index, which is the silent merge the doc forbids. The
            # tuple is re-read from any existing manifest and compared rather
            # than assumed, because trusting the digest to imply the tuple is
            # what makes such a bug invisible.
            existing = read_manifest(dir)
            if existing && !same_identity?(existing, repo, fork, rev, schema.id)
              return Envelope.refuse(
                "schema_collision",
                "digest #{digest[0, 12]} already holds #{existing['repo']}/#{existing['fork']}@" \
                "#{existing['rev']} under schema #{existing['schema_id']}"
              )
            end

            FileUtils.mkdir_p(dir)
            built = {}
            coverage = {}
            counts = {}

            schema.dimensions.each do |dimension|
              result = dimension.build(root: root)
              built[dimension.name] = result.postings
              coverage[dimension.name] = result.coverage
              counts[dimension.name] = result.postings.sum { |_path, lines| lines.size }
              File.write(
                File.join(dir, "#{dimension.name}.json"),
                JSON.generate("postings" => result.postings, "coverage" => result.coverage)
              )
            end

            manifest = {
              "format" => FORMAT,
              "digest" => digest,
              "repo" => repo,
              "fork" => fork,
              "rev" => rev,
              "schema_id" => schema.id,
              "dimensions" => schema.names.map(&:to_s),
              "lines_indexed" => counts.transform_keys(&:to_s)
            }
            File.write(File.join(dir, MANIFEST), JSON.pretty_generate(manifest) + "\n")

            Envelope.ok(
              index: new(
                digest: digest, repo: repo, fork_name: fork, rev: rev, schema: schema,
                postings: built, coverage: coverage, built_dimensions: schema.names
              ),
              digest: digest,
              lines_indexed: counts
            )
          end
        end

        # Warms an index into memory. plan_vv-code-search measures the bound "at
        # lookup, not at index", and this is the boundary between them: open
        # pays the read, lookup pays a hash probe.
        def open(digest:, store:)
          Envelope.never_raise do
            dir = File.join(store, digest)
            manifest = read_manifest(dir)
            return Envelope.refuse("index_unreadable", "no index at #{digest[0, 12]} in #{store}") if manifest.nil?

            schema = Schema.named(manifest["schema_id"])
            if schema.nil?
              return Envelope.refuse(
                "schema_unknown",
                "index #{digest[0, 12]} was built under schema #{manifest['schema_id'].inspect}, which is not registered here"
              )
            end

            postings = {}
            coverage = {}
            built = []
            manifest.fetch("dimensions", []).each do |name|
              path = File.join(dir, "#{name}.json")
              next unless File.file?(path)

              blob = JSON.parse(File.read(path))
              postings[name.to_sym] = rehydrate(blob["postings"])
              coverage[name.to_sym] = blob["coverage"]
              built << name.to_sym
            end

            Envelope.ok(
              index: new(
                digest: digest, repo: manifest["repo"], fork_name: manifest["fork"],
                rev: manifest["rev"], schema: schema, postings: postings,
                coverage: coverage, built_dimensions: built
              )
            )
          end
        end

        def read_manifest(dir)
          path = File.join(dir, MANIFEST)
          return nil unless File.file?(path)

          JSON.parse(File.read(path))
        rescue JSON::ParserError, SystemCallError, IOError
          nil
        end

        private

        def same_identity?(manifest, repo, fork, rev, schema_id)
          manifest["repo"] == repo && manifest["fork"] == fork &&
            manifest["rev"] == rev && manifest["schema_id"] == schema_id
        end

        # JSON object keys are strings; line numbers are Integers everywhere
        # else in this gem. Normalising on the way in means no lookup has to
        # remember which side of the serialisation boundary it is on.
        def rehydrate(raw)
          return {} if raw.nil?

          raw.each_with_object({}) do |(path, lines), out|
            out[path] = lines.each_with_object({}) { |(no, entries), acc| acc[Integer(no)] = entries }
          end
        end
      end

      # Did this dimension get built for this rev? The difference between "no"
      # and "built, nothing on that line" is the whole grep lesson.
      def built?(name) = built_dimensions.include?(name)

      # Is this dimension entitled to call silence on this path evidence?
      def covers?(name, path)
        return false unless built?(name)

        declared = coverage[name]
        declared.nil? || declared.include?(path)
      end
    end
  end
end
