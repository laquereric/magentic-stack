# frozen_string_literal: true

module Vv
  module DependencyOrch
    module Adapters
      # Whether a commit is reachable -- and the refusal that makes the answer
      # worth having.
      #
      # THE TRAP: a shallow clone lies about ancestry. `merge-base
      # --is-ancestor` and `--contains` answer from LOCAL reachability, so a
      # pinned commit can look orphaned when it is not. The commit is fine; the
      # checkout simply does not have the history to see it.
      #
      # This adapter therefore refuses to answer ancestry from a shallow
      # checkout, rather than answering and being wrong. A refusal an operator
      # can act on ("run git fetch --unshallow, or ask the remote") beats a
      # confident "orphaned" that sends them to re-pin something that never
      # moved.
      #
      # Asking the remote -- the GitHub compare API -- is S5/S6 work and needs a
      # credential this gem is not allowed to hold. Until then the honest answer
      # for a shallow tree is `not_indexed`, and the honest answer for a full
      # tree is a real one.
      class GitRemote < Base
        def available?
          return @available unless @available.nil?

          status, = run(%w[git --version], timeout: 5)
          @available = status == :ok
        end

        def shallow?(root)
          status, out, = run(["git", "-C", root, "rev-parse", "--is-shallow-repository"], timeout: 5)
          status == :ok && out.strip == "true"
        end

        # Is this revision present in this checkout?
        def placement_for(revision, root:, at: nil)
          at ||= File.basename(File.expand_path(root))

          # SHALLOWNESS UNDERMINES ABSENCE, NOT PRESENCE.
          #
          # An earlier version returned unreachable for a shallow checkout
          # WITHOUT LOOKING, and that threw away good evidence: `cat-file -e`
          # succeeding means the object is right there, and no amount of
          # truncated history makes that less true. Every pinned revision in
          # magentic-stack came back unreachable because of it -- five of the six
          # submodules are shallow and most of them have the very commit being
          # asked about, checked out.
          #
          # The asymmetry is the same one the whole gem turns on. A source that
          # cannot prove a negative can still prove a positive, so the shallow
          # rule belongs on the FAILURE branch only.
          depth_limited = shallow?(root)

          round_trip(kind: :git_remote, at: at,
                     argv: ["git", "-C", root, "cat-file", "-e", "#{revision}^{commit}"]) do |status, _out, err|
            if status == :ok
              [:present, { root: root, shallow: depth_limited }]
            elsif err.to_s.match?(/Not a valid object name|could not get object info|bad file/i) || status == :failed
              if depth_limited
                [:unreachable,
                 "#{root} is a shallow clone and does not have #{Identity.short(revision)}. That " \
                 "establishes nothing: local reachability cannot decide existence from truncated " \
                 "history. Ask the remote, or git fetch --unshallow."]
              else
                [:absent, "a full checkout at #{root} does not contain #{Identity.short(revision)}"]
              end
            else
              [:unreachable, "git cat-file failed: #{err.to_s.strip}"]
            end
          end
        end

        # Every checkout a revision could live in: the roots, and each root's
        # submodule working directories.
        #
        # A PIN IS ALMOST NEVER IN THE SUPERPROJECT. magentic-stack's pinned
        # revisions are submodule commits -- `git cat-file -e` in the parent
        # answers "not a valid object name" for every one of them, which is
        # true and useless. Searching only the roots is why these resources had
        # no placement at all rather than a wrong one.
        # Every checkout a revision could live in: the root, plus the
        # submodule working directories it was TOLD about.
        #
        # A PIN IS ALMOST NEVER IN THE SUPERPROJECT. magentic-stack's pinned
        # revisions are submodule commits -- `cat-file -e` in the parent answers
        # "not a valid object name" for every one of them, which is true and
        # useless. Searching only the roots is why these resources had no
        # placement at all rather than a wrong one.
        #
        # The paths arrive as an argument rather than being discovered here.
        # Discovering them means reading .gitmodules, which is a pin source this
        # gem does not parse -- Adapters::Pins asks the index instead.
        def checkouts(root, submodules: [])
          out = [root]
          Array(submodules).each do |rel|
            path = File.join(root, rel)
            # An UNINITIALISED submodule is an empty directory with no .git.
            # Skipping it is right: it cannot answer, and including it would
            # produce a completed "no" from a checkout that holds nothing --
            # manufacturing exactly the false absence this adapter refuses.
            out << path if File.exist?(File.join(path, ".git"))
          end
          out
        end

        # ONE placement for a revision, resolved across every checkout.
        #
        # The combination rule is the authority rule again, applied within a
        # kind. `present` if any checkout holds it. `absent` ONLY if every
        # checkout completed an answer AND none of them was shallow -- because
        # a shallow clone that does not have a commit has not established
        # anything, and letting it vote would reproduce the exact ancestry lie
        # this adapter refuses elsewhere.
        def placement_across(revision, roots:, submodules: [])
          return Placement.never_looked(kind: :git_remote, at: "git",
                                        because: "git is not available here") unless available?

          candidates = Array(roots).flat_map { |r| checkouts(r, submodules: submodules) }.uniq
          if candidates.empty?
            return Placement.never_looked(kind: :git_remote, at: "git",
                                          because: "no checkout was supplied to look in")
          end

          seen = candidates.map { |c| [c, placement_for(revision, root: c, at: short_at(c))] }

          found = seen.find { |(_c, pl)| pl.state == :present }
          return found.last if found

          blocked = seen.select { |(_c, pl)| pl.state == :unreachable }
          if blocked.any?
            return Placement.unreachable(
              kind: :git_remote, at: "git",
              because: "#{Identity.short(revision)} is in none of the #{candidates.length} checkout(s) " \
                       "that could answer, and #{blocked.length} of them are shallow " \
                       "(#{blocked.map { |(c, _)| File.basename(c) }.join(', ')}) -- a shallow clone " \
                       "that lacks a commit has established nothing. Ask the remote, or " \
                       "git fetch --unshallow."
            )
          end

          Placement.absent(
            kind: :git_remote, at: "git",
            because: "every one of #{candidates.length} full checkout(s) completed the lookup and " \
                     "none contains #{Identity.short(revision)}"
          )
        end

        def short_at(path)
          File.basename(File.expand_path(path))
        end

        # Does `revision` land on `branch`? Only answerable from a full tree.
        def contains?(revision, root:, branch: "HEAD")
          return Envelope.refuse("adapter_unavailable", "git is not available here") unless available?

          if shallow?(root)
            return Envelope.refuse(
              "not_indexed",
              "#{root} is shallow. `merge-base --is-ancestor` answers from local reachability, " \
              "so it would report orphaned for a commit that is not. This gem will not answer " \
              "ancestry from a checkout that cannot see the history."
            )
          end

          status, _out, err = run(["git", "-C", root, "merge-base", "--is-ancestor", revision, branch])
          case status
          when :ok then Envelope.ok(contains: true, revision: revision, branch: branch)
          when :failed then Envelope.ok(contains: false, revision: revision, branch: branch)
          else Envelope.refuse("unreachable", "git merge-base failed: #{err.to_s.strip}")
          end
        end
      end
    end
  end
end
