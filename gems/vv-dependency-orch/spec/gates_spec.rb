# frozen_string_literal: true

# Gates that are about the SOURCE rather than about a value.
#
# "Zero jobs is a fail. A checker that has never been planted is not a gate."
# Each of these is planted below by asserting on the real tree: add the thing
# the gate forbids and the example goes red.
RSpec.describe "source gates" do
  ROOT = File.expand_path("..", __dir__)
  LIB = Dir[File.join(ROOT, "lib", "**", "*.rb")].sort

  it "has files to check" do
    expect(LIB).not_to be_empty
  end

  # GATE: Rails is never loaded.
  #
  # This is the structural half of ADR 0019's content-blind invariant. The CLI
  # may read content; the routing path may not, and must not be ABLE to. A gem
  # with its own load path makes that a fact about the program rather than a
  # promise about the reviewer -- but only while nothing here reaches back.
  describe "Rails is never loaded" do
    FORBIDDEN_CONSTANTS = %w[Rails ActiveSupport ActiveRecord ActionController RailsCpcp].freeze

    it "requires nothing from rails" do
      offenders = LIB.reject do |file|
        File.read(file).scan(/^\s*require(?:_relative)?\s+["']([^"']+)["']/).flatten
            .none? { |req| req.match?(/\A(rails|active_?support|active_?record|action_|rails-cpcp)/) }
      end

      expect(offenders).to be_empty, "these require Rails: #{offenders.join(', ')}"
    end

    it "names no Rails constant in code" do
      offenders = LIB.select do |file|
        code = File.read(file).lines.grep_v(/^\s*#/).join
        FORBIDDEN_CONSTANTS.any? { |const| code.match?(/(?<![\w:"'-])#{const}(::|\.|\b)/) }
      end

      expect(offenders).to be_empty, "these name a Rails constant: #{offenders.join(', ')}"
    end

    it "loads with app/ and config/ absent from the load path" do
      expect($LOAD_PATH.grep(%r{/(app|config)\z})).to be_empty
      expect(defined?(Rails)).to be_nil
    end
  end

  # GATE: the pin index is not reimplemented.
  #
  # The one most likely to be violated by accident, because parsing a pin file
  # is always five minutes of work and always looks easier than wiring the
  # dependency. Two answers to "which lines carry a pin" is how they start to
  # disagree -- the same argument ADR 0038 makes about two copies of a gem.
  # Comments are stripped before matching. The gate is about what the code
  # DOES; a comment naming a pin file is how this gem explains what it delegates,
  # and a checker that fires on its own documentation is one people delete.
  it "parses no pin source itself" do
    pin_sources = /Gemfile\.lock|\.pin\.json|\.gitmodules|base_image_digests|docker-compose/

    offenders = LIB.select do |file|
      File.read(file).lines.grep_v(/^\s*#/).join.match?(pin_sources)
    end

    expect(offenders).to be_empty,
                         "these look like they parse pin sources; vv-code-search has that job: #{offenders.join(', ')}"
  end

  # GATE: read-only by default.
  #
  # There is no write path in the POC at all, so the gate is that it stays that
  # way. Asserting on the ALLOWLIST rather than on a denylist is deliberate: a
  # denylist has to anticipate `docker container rm`, and an allowlist does not
  # have to anticipate anything.
  describe "read-only" do
    ALLOWED_ARGV = [
      %w[docker version],
      %w[docker image ls],
      %w[docker image inspect],
      %w[docker buildx version],
      %w[docker buildx imagetools inspect],
      %w[git --version],
      %w[git -C],          # followed by a path, then a read-only subcommand
      %w[git rev-parse]
    ].freeze

    READ_ONLY_GIT = %w[rev-parse cat-file merge-base --version].freeze

    # Collects every argv literal that starts with docker or git, INCLUDING the
    # tokens that follow an interpolated variable. An earlier version of this
    # stopped at the first non-literal element, so `["git", "-C", root,
    # "rev-parse", ...]` came back as just `git -C` and the gate could not see
    # which subcommand was being run -- a checker blind to exactly the token it
    # exists to inspect.
    def argv_literals(source)
      literals = []
      source.scan(/%w\[(docker|git)([^\]]*)\]/) do |(head, rest)|
        literals << [head, *rest.split(/\s+/).reject(&:empty?)]
      end
      source.scan(/\[\s*"(docker|git)"(.*?)\]/m) do |(head, rest)|
        literals << [head, *rest.scan(/"([^"]*)"/).flatten]
      end
      literals
    end

    it "shells out only to read-only commands" do
      offenders = LIB.flat_map do |file|
        argv_literals(File.read(file)).reject do |tokens|
          if tokens.first == "git"
            (tokens & READ_ONLY_GIT).any?
          else
            ALLOWED_ARGV.any? { |allowed| tokens.first(allowed.length) == allowed }
          end
        end.map { |tokens| "#{File.basename(file)}: #{tokens.join(' ')}" }
      end

      expect(offenders).to be_empty, "not on the read-only allowlist: #{offenders.join('; ')}"
    end

    it "actually found the commands, so the allowlist is not passing vacuously" do
      found = LIB.flat_map { |file| argv_literals(File.read(file)) }
      expect(found.length).to be >= 6
    end
  end

  # GATE: no rake task holds domain logic.
  #
  # If a task branched on a domain fact, the CLI that comes later could not be a
  # second presentation of the same model -- it would have to reimplement the
  # branch, and the two surfaces would begin to answer differently. Three lines
  # per task: read arguments, call one library function, print the envelope.
  it "keeps the rake tasks thin" do
    source = File.read(File.join(ROOT, "lib/vv/dependency_orch/tasks.rb"))
    install = source[/def install.*/m]

    expect(install).not_to be_nil

    # Comments and string literals are stripped first. A task's `desc` is
    # English -- "Reverse: if this moves, which lines declare it" -- and a gate
    # that reads prose as a branch teaches people to write worse descriptions.
    code = install.lines.grep_v(/^\s*#/).join.gsub(/"[^"]*"/, '""')
    conditionals = code.lines.grep(/\b(if|unless|case|elsif|while)\b/)

    expect(conditionals).to be_empty,
                            "a rake task branched on something: #{conditionals.map(&:strip).join(' | ')}"
  end

  # GATE: the graph export is the source for any view.
  #
  # The canvas comes later and renders THIS. A board asserting an edge the
  # export does not carry is the failure; here, the smaller version -- mermaid
  # is derived from the same document as the JSON, never assembled separately.
  it "derives mermaid from the same document as the json" do
    source = File.read(File.join(ROOT, "lib/vv/dependency_orch/export.rb"))
    mermaid_body = source[/def mermaid.*?\n      end/m]

    expect(mermaid_body).not_to be_nil
    expect(mermaid_body).not_to match(/graph\.(resources|edges)/),
                                "mermaid reached into the Graph instead of reading the exported document"
  end
end
