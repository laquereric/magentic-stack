# frozen_string_literal: true

require "open3"

module Vv
  module DependencyOrch
    module Adapters
      # The only place in this gem that may produce `present` or `absent`.
      #
      # That is the design, not a coincidence of layering. Those two states are
      # the only ones that are evidence about the world, and both require a
      # round trip that actually completed. Every other module can reach
      # `unreachable` and `not_indexed` and cannot reach these -- so "an adapter
      # that times out must not report absent" is a structural fact rather than
      # a rule each adapter author has to remember.
      #
      # `round_trip` enforces it by ORDERING: on a timeout it returns before the
      # interpreting block is ever called. The block cannot mis-decide a
      # timeout, because the block does not run.
      class Base
        # 20s is chosen against the failure it protects: a VPS behind a dropped
        # route, where TCP will sit for minutes. An operator waiting on
        # `orch:drift` should get `unreachable` while still looking at the
        # terminal, because the alternative is that they Ctrl-C and learn
        # nothing at all.
        DEFAULT_TIMEOUT = 20

        attr_reader :timeout

        def initialize(timeout: DEFAULT_TIMEOUT)
          @timeout = timeout
        end

        # Subclasses answer: is the tool this adapter shells out to even here?
        def available? = false

        def name = self.class.name.split("::").last

        # Runs argv, collecting both streams, and kills the child at the
        # deadline. Returns [:ok | :failed | :timeout | :missing, stdout, stderr].
        #
        # :missing is separated from :failed because "docker is not installed"
        # and "docker said no" are different facts about the world, and only the
        # second one is about the resource.
        def self.run(argv, timeout: DEFAULT_TIMEOUT)
          # BINARY, not UTF-8. The registry adapter digests these bytes to
          # recover an index digest, and a re-encode would change the hash;
          # appending a chunk that is not valid UTF-8 to a UTF-8 buffer also
          # raises, which would surface as an internal_error on a perfectly
          # reachable registry.
          out = String.new(encoding: Encoding::BINARY)
          err = String.new(encoding: Encoding::BINARY)
          status = nil

          begin
            Open3.popen3(*argv) do |stdin, stdout, stderr, wait_thr|
              stdin.close
              readers = [stdout, stderr]
              deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

              until readers.empty?
                remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
                if remaining <= 0
                  begin
                    Process.kill("KILL", wait_thr.pid)
                  rescue StandardError
                    nil
                  end
                  return [:timeout, out, err]
                end

                ready = IO.select(readers, nil, nil, remaining)
                next if ready.nil?

                ready[0].each do |io|
                  begin
                    chunk = io.read_nonblock(65_536)
                    (io.equal?(stdout) ? out : err) << chunk
                  rescue EOFError
                    readers.delete(io)
                  rescue IO::WaitReadable
                    nil
                  end
                end
              end

              status = wait_thr.value
            end
          rescue Errno::ENOENT
            return [:missing, out, "#{argv.first} is not on PATH"]
          end

          [status&.success? ? :ok : :failed, out, err]
        end

        def run(argv, timeout: self.timeout) = self.class.run(argv, timeout: timeout)

        private

        # Yields (status, stdout, stderr) ONLY for a completed round trip, and
        # expects back one of:
        #
        #   [:present, details_hash]
        #   [:absent,  because]
        #   [:unreachable, because]      -- for a completion that still proves nothing
        #
        # A block that returns anything else is a bug in the adapter, and it is
        # reported as unreachable rather than guessed at: an unrecognised
        # verdict is precisely the case where we do not know, and the safe
        # direction is always away from `absent`.
        def round_trip(kind:, at:, argv:, timeout: self.timeout)
          unless available?
            return Placement.unreachable(
              kind: kind, at: at,
              because: "#{name} is not available here; nothing was asked of #{at}"
            )
          end

          status, out, err = run(argv, timeout: timeout)

          case status
          when :timeout
            return Placement.unreachable(
              kind: kind, at: at,
              because: "timed out after #{timeout}s running #{argv.first}; silence is not absence"
            )
          when :missing
            return Placement.unreachable(
              kind: kind, at: at,
              because: err.strip
            )
          end

          verdict, payload = yield(status, out, err)

          case verdict
          when :present
            Placement.present(kind: kind, at: at, details: payload || {})
          when :absent
            Placement.absent(kind: kind, at: at, because: payload.to_s)
          when :unreachable
            Placement.unreachable(kind: kind, at: at, because: payload.to_s)
          else
            Placement.unreachable(
              kind: kind, at: at,
              because: "#{name} returned an unrecognised verdict #{verdict.inspect}"
            )
          end
        end
      end
    end
  end
end
