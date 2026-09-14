# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module Vv
  module DependencyOrch
    module Adapters
      # Consumes vv-code-search. Does not reimplement it.
      #
      # That gem already indexes pin lines across a tree, and -- the part that
      # matters here -- it keeps DECLARES apart from REFERENCES. Rebuilding that
      # would produce a second answer to "which lines carry a pin", and two
      # answers to one question is how they start to disagree. So there is no
      # lockfile regex in this file, and the gate plants one.
      #
      # SOFT DEPENDENCY, ON PURPOSE. vv-code-search is closed (ADR 0038) and
      # sits beside this gem in gems/. Declaring it in the gemspec would make
      # a standalone `bundle` of this gem fail rather than degrade. It is
      # required lazily; absence is `not_indexed`.
      class Pins
        SCHEMA = "magentic-pins"

        # A digest-shaped pin joins the resource graph; anything else stays a
        # pin string. That join is what makes `drift` possible at all: the
        # declaration in a file and the image in a daemon become the same node.
        OCI_DIGEST = /\Asha256:[0-9a-f]{64}\z/
        GIT_REV = /\A[0-9a-f]{40}\z/

        class << self
          # Where vv-code-search lives. Configured, never guessed -- a search of
          # likely sibling directories would sometimes find the wrong checkout,
          # and the failure would be a graph built against another tree's pins.
          def gem_path = ENV["VV_CODE_SEARCH_PATH"]

          def load!
            return @loaded unless @loaded.nil?

            path = gem_path
            $LOAD_PATH.unshift(File.join(path, "lib")) if path && Dir.exist?(File.join(path, "lib"))

            @loaded = begin
              require "vv/code_search"
              true
            rescue LoadError
              false
            end
          end

          def available? = load!

          def unavailable_envelope
            Envelope.refuse(
              "not_indexed",
              "vv-code-search is not loadable, so no tree has been indexed for pins. " \
              "Set VV_CODE_SEARCH_PATH to magentic-stack/gems/vv-code-search. " \
              "This gem will not parse pin files itself."
            )
          end
        end

        attr_reader :store, :owns_store

        # The store is a TEMP directory by default, and that is consistent with
        # "no persisted graph" rather than a contradiction of it: the graph this
        # gem computes is not persisted. vv-code-search's index is its own
        # artefact, expensive to build and explicitly cache-shaped, so reusing a
        # warm one is offered and opt-in via VV_CODE_SEARCH_STORE.
        def initialize(store: ENV["VV_CODE_SEARCH_STORE"])
          @owns_store = store.nil?
          @store = store || Dir.mktmpdir("vv-dependency-orch-pins-")
        end

        def available? = self.class.available?

        # Builds (or reuses) the pins index for a tree. Returns an envelope with
        # the index in :index -- vv-code-search's own object, passed through
        # rather than wrapped, so there is one representation of it.
        def index_for(root:, repo: nil, rev: nil)
          return self.class.unavailable_envelope unless available?

          Envelope.never_raise do
            root = File.expand_path(root)
            repo ||= File.basename(root)
            rev ||= revision_of(root)

            result = ::Vv::CodeSearch::Index.build(
              repo: repo, rev: rev, schema: SCHEMA, root: root, store: store
            )

            # vv-code-search returns its own envelope with its own closed reason
            # set. Passing its reason through unchanged would leak a vocabulary
            # our callers do not have; mapping it to `not_indexed` is accurate,
            # because from our side every one of its failures means the pins for
            # this tree were not indexed.
            unless result[:ok]
              return Envelope.refuse(
                "not_indexed",
                "vv-code-search refused to index #{root}: #{result[:reason]} -- #{result[:because]}"
              )
            end

            Envelope.ok(index: result[:index], repo: repo, rev: rev,
                        lines_indexed: result[:lines_indexed])
          end
        end

        # Every pin line in the tree, as edges.
        #
        # This walks `index.postings[:pins]`, which is vv-code-search's own
        # output structure -- reading its results, not re-deriving them. The
        # distinction is the whole point of the boundary: that gem answers "what
        # does this line say"; this one answers "and is it still true, and who
        # else cares".
        def edges(index:, repo:)
          return self.class.unavailable_envelope unless available?

          Envelope.never_raise do
            postings = index.postings[:pins] || {}
            out = []

            # digest -> the names the declarations give it. The REGISTRY cannot
            # be asked about a bare digest: `imagetools inspect` takes
            # repository@digest, so a digest with no repository is one nothing
            # can resolve. pin_node deliberately drops the name from the node id
            # -- identity is the digest, not the name -- which left the name
            # nowhere at all until this carried it alongside.
            names = Hash.new { |h, k| h[k] = [] }

            postings.each do |path, lines|
              lines.each do |line_no, entries|
                entries.each do |entry|
                  kind = entry["kind"] == "declares" ? :declares : :references
                  node = pin_node(entry)
                  name = entry["name"].to_s
                  names[node] << name unless name.empty?
                  out << Edge.new(
                    kind: kind,
                    from: line_node(repo, path, line_no),
                    to: node,
                    where: { repo: repo, path: path, line: line_no },
                    because: entry["source"]
                  )
                end
              end
            end

            Envelope.ok(edges: out, names: names.transform_values(&:uniq))
          end
        end

        # Where the submodule checkouts are, ASKED rather than re-parsed.
        #
        # The git adapter needs these to resolve a pinned revision: this stack's
        # pins are submodule commits, and `cat-file` in the superproject answers
        # "not a valid object name" for every one of them.
        #
        # Reads a FIELD the index publishes, not the human-readable `source`
        # sentence beside it. Two earlier attempts were refused by this gem's
        # own gates and both refusals were right: reading the file directly is
        # parsing a pin source, and regexing the description back out would have
        # made another gem's prose into an API. The field exists because this
        # consumer needed it.
        SUBMODULE_PATH_KEY = "submodule_path"

        def submodule_paths(index:)
          return [] unless available?

          out = []
          (index.postings[:pins] || {}).each_value do |lines|
            lines.each_value do |entries|
              entries.each do |entry|
                value = entry[SUBMODULE_PATH_KEY].to_s.strip
                out << value unless value.empty?
              end
            end
          end
          out.uniq
        end

        # The reverse question, delegated. vv-code-search owns the scan; we own
        # nothing about it except the call.
        def lines_for_pin(index:, pin:, kinds: %w[declares references])
          return self.class.unavailable_envelope unless available?

          result = ::Vv::CodeSearch::Lookup.lines_for_pin(index: index, pin: pin, kinds: kinds)
          return Envelope.refuse("not_indexed", "#{result[:reason]}: #{result[:because]}") unless result[:ok]

          Envelope.ok(pin: pin, lines: result[:lines])
        end

        def cleanup
          FileUtils.remove_entry(store) if owns_store && Dir.exist?(store)
        rescue StandardError
          nil
        end

        private

        def line_node(repo, path, line_no) = "line:#{repo}/#{path}#L#{line_no}"

        # A digest-valued pin becomes the digest node itself, so a line in a
        # Dockerfile and an image in the daemon are ONE node and `drift` has
        # something to compare. A version-valued pin stays a pin string, because
        # "rubygems:rake:13.0.6" has no placement to disagree with.
        def pin_node(entry)
          version = entry["version"].to_s
          return version if version.match?(OCI_DIGEST) || version.match?(GIT_REV)

          entry["pin"].to_s
        end

        def revision_of(root)
          status, out, = Base.run(["git", "-C", root, "rev-parse", "HEAD"], timeout: 5)
          return out.strip if status == :ok && !out.strip.empty?

          # No git, or not a checkout. The tuple vv-code-search keys its index
          # by needs SOMETHING here, and "unversioned" is honest -- it says the
          # index is not pinned to a revision, which is true and which the
          # default temp store makes harmless.
          "unversioned"
        end
      end
    end
  end
end
