# frozen_string_literal: true

require "json"

module Vv
  module CodeSearch
    module Dimensions
      # Stage 1: which pin does this line belong to, and who cares when it moves.
      #
      # plan_vv-code-search starts here rather than at embeddings for a reason it
      # states plainly -- "a lockfile is not an AST" -- and the three questions it
      # wants answered by lookup instead of by `rg` are all pin questions:
      #
      #   this line -- which pin does it belong to?
      #   this pin moved -- which lines in this repo care?
      #   this fork -- which pins diverged?          (stage 3, not here)
      #
      # DECLARES vs REFERENCES is the distinction that makes the second question
      # answerable. A lockfile line that reads `rake (13.0.6)` DECLARES the pin:
      # it is where the version is decided. A gemspec line `add_dependency "rake"`
      # REFERENCES it: it is a line that cares when the pin moves but does not
      # choose it. Collapsing the two gives you a reverse index that cannot tell
      # "change this to move the pin" from "re-check this because the pin moved",
      # and the second set is the one a maintainer needs on an incoming PR.
      #
      # Absence is a signal. A line with no pin returns an empty list, not a
      # refusal -- see Lookup for why that distinction is load-bearing.
      class Pins < Dimension
        # Every pin source this dimension knows how to read. A file that matches
        # none of these is not scanned, which is why `covers?` exists: a repo
        # family whose pins live somewhere else gets zero postings and should be
        # told so at build time rather than discovering it as silence at lookup.
        LOCKFILE = /(?:^|\/)Gemfile\.lock$/.freeze
        PIN_JSON = /\.pin\.json$/.freeze
        GITMODULES = /(?:^|\/)\.gitmodules$/.freeze
        DIGEST_JSON = /(?:^|\/)base_image_digests\.json$/.freeze
        COMPOSE = /(?:^|\/)(?:docker-)?compose[\w.-]*\.ya?ml$/.freeze
        DOCKERFILE = /(?:^|\/)Dockerfile[\w.-]*$/.freeze

        SOURCES = [LOCKFILE, PIN_JSON, GITMODULES, DIGEST_JSON, COMPOSE, DOCKERFILE].freeze

        # `    rake (13.0.6)` under specs: -- four spaces, name, parenthesised
        # version. Six spaces is that gem's own dependency, which references
        # rather than declares.
        LOCK_SPEC = /\A {4}([a-zA-Z0-9_.\-]+) \(([^)]+)\)\s*\z/.freeze
        LOCK_SUBDEP = /\A {6}([a-zA-Z0-9_.\-]+)(?: \(([^)]*)\))?\s*\z/.freeze
        LOCK_DEP = /\A {2}([a-zA-Z0-9_.\-]+)(?:!|\s|\z)/.freeze

        OCI_DIGEST = /([\w.\-\/]+)@(sha256:[0-9a-f]{64})/.freeze
        BARE_SHA = /\b([0-9a-f]{40})\b/.freeze

        class << self
          def name = :pins

          # A posting list keyed by line. Answered with a hash lookup.
          def point_query? = true

          def covers?(relative_path)
            SOURCES.any? { |re| re.match?(relative_path) }
          end

          def build(root:)
            postings = {}
            each_source(root) do |relative, absolute|
              entries = parse(relative, absolute)
              postings[relative] = entries unless entries.empty?
            end
            # coverage: nil -- this dimension walks the WHOLE tree and then
            # selects pin sources from it, so a line with no pin genuinely has
            # no pin. That is the case plan_vv-code-search names directly: an
            # indexed rev with no pin on that line is ok:true with pins: [],
            # because absence is a signal.
            Built.new(postings: normalise(postings), coverage: nil)
          end

          # Walks the tree once. .git is skipped for the obvious reason; vendor
          # and node_modules are skipped because a vendored lockfile declares
          # pins for a tree this repo does not govern, and mixing those into the
          # reverse index makes "which lines care" answer with lines nobody here
          # can change.
          SKIP = %w[.git node_modules tmp log .venv __pycache__].freeze

          def each_source(root)
            root = File.expand_path(root)
            stack = [root]
            while (dir = stack.pop)
              Dir.children(dir).each do |child|
                next if SKIP.include?(child)

                absolute = File.join(dir, child)
                if File.directory?(absolute)
                  stack << absolute unless File.symlink?(absolute)
                  next
                end
                relative = absolute.delete_prefix("#{root}/")
                yield relative, absolute if covers?(relative)
              end
            end
          end

          def parse(relative, absolute)
            text = File.read(absolute, encoding: "UTF-8", invalid: :replace, undef: :replace)
            case relative
            when LOCKFILE then parse_lockfile(text)
            when PIN_JSON then parse_pin_json(relative, text)
            when GITMODULES then parse_gitmodules(text)
            else parse_digests(text)
            end
          rescue SystemCallError, IOError
            # An unreadable pin source is not a pin-free file. It contributes no
            # postings, and build_report counts it so the difference is visible
            # instead of being indistinguishable from "no pins here".
            {}
          end

          private

          # Bundler's lockfile has three line shapes that matter and they mean
          # different things. `specs:` entries decide a version; DEPENDENCIES
          # entries name what this tree asked for; the indented lines under a
          # spec are that gem's own requirements.
          def parse_lockfile(text)
            out = Hash.new { |h, k| h[k] = [] }
            section = nil
            text.each_line.with_index(1) do |line, no|
              stripped = line.rstrip
              case stripped
              when /\A[A-Z]/ then section = stripped
              end

              if (m = LOCK_SPEC.match(stripped))
                out[no] << entry("declares", "rubygems", m[1], m[2], "Gemfile.lock specs")
              elsif (m = LOCK_SUBDEP.match(stripped))
                out[no] << entry("references", "rubygems", m[1], m[2], "Gemfile.lock transitive requirement")
              elsif section == "DEPENDENCIES" && (m = LOCK_DEP.match(stripped))
                out[no] << entry("references", "rubygems", m[1], nil, "Gemfile.lock DEPENDENCIES")
              end
            end
            out
          end

          # upstreams/manifests/*.pin.json. `pinned_revision` is where the pin is
          # decided; `rollback_target` names a revision this repo intends to be
          # able to return to, which is a reference and not a declaration -- a
          # rollback target that moves is a different problem from a pin that
          # moves, and merging them hides both.
          def parse_pin_json(relative, text)
            out = Hash.new { |h, k| h[k] = [] }
            name = File.basename(relative, ".pin.json")
            text.each_line.with_index(1) do |line, no|
              if (m = /"pinned_revision"\s*:\s*"([^"]+)"/.match(line))
                out[no] << entry("declares", "git", name, m[1], "pin manifest")
              elsif (m = /"rollback_target"\s*:\s*"([^"]+)"/.match(line))
                out[no] << entry("references", "git", name, m[1], "pin manifest rollback target")
              elsif (m = /"submodule_path"\s*:\s*"([^"]+)"/.match(line))
                out[no] << entry("references", "git", name, nil, "pin manifest submodule path #{m[1]}")
              end
            end
            out
          end

          # The gitlink SHA itself lives in the tree object, not in .gitmodules,
          # so these lines reference the submodule rather than declaring its
          # revision. Saying "declares" here would be a lie that a reverse-index
          # consumer would act on.
          def parse_gitmodules(text)
            out = Hash.new { |h, k| h[k] = [] }
            current = nil
            text.each_line.with_index(1) do |line, no|
              if (m = /\A\[submodule "([^"]+)"\]/.match(line.strip))
                current = m[1]
                out[no] << entry("references", "git", current, nil, ".gitmodules section")
              elsif current && (m = /\A(path|url)\s*=\s*(.+)\z/.match(line.strip))
                out[no] << entry("references", "git", current, nil, ".gitmodules #{m[1]} #{m[2]}")
              end
            end
            out
          end

          # OCI digests and bare 40-hex SHAs, wherever they appear: compose
          # files, Dockerfiles, base_image_digests.json. A digest is a pin no
          # matter which file shape it arrived in.
          def parse_digests(text)
            out = Hash.new { |h, k| h[k] = [] }
            text.each_line.with_index(1) do |line, no|
              line.scan(OCI_DIGEST) do |image, digest|
                out[no] << entry("declares", "oci", image, digest, "digest-pinned image")
              end
              next if out[no].any?

              line.scan(BARE_SHA) do |(sha)|
                out[no] << entry("declares", "git", nil, sha, "pinned revision")
              end
            end
            out
          end

          def entry(kind, ecosystem, name, version, source)
            {
              "kind" => kind,
              "ecosystem" => ecosystem,
              "name" => name,
              "version" => version,
              "pin" => [ecosystem, name, version].compact.join(":"),
              "source" => source
            }
          end
        end
      end
    end
  end
end
