# frozen_string_literal: true

require "open3"
require "json"
require "fileutils"
require "rbconfig"

module Vv
  module CodeSearch
    # The trigram engine. microsoft/tgrep, invoked as a binary.
    #
    # plan_vv-code-search names the lexical primitive as "posting list / trigram
    # (grep-class, indexed)". The posting list is still tokens-per-line, because
    # the hover asks "what is on THIS line" and a trigram index cannot answer
    # that without reading the file. The trigram half is the OTHER question --
    # "where is this string" -- and that is what used to stay `rg` on a cold
    # tree. Once a tree is in our set, that question is tgrep against an index
    # we built at ingest.
    #
    # This file is the only place the gem talks to tgrep. Lookup.call never
    # comes here: the hover bound is a hash probe, and a process spawn would
    # spend it. Lookup.search does, and says so.
    #
    # The binary is discovered, never bundled. VV_TGREP wins, then PATH. A
    # missing binary is `tgrep_missing`, not an empty hit list: silence from a
    # tool we did not run is not evidence.
    module Tgrep
      INDEX_DIR = "tgrep"
      INDEX_TIMEOUT = 300
      SEARCH_TIMEOUT = 30

      module_function

      def binary
        configured = ENV["VV_TGREP"]
        return configured if configured && !configured.empty? && File.file?(configured)

        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
          next if dir.empty?

          candidate = File.join(dir, "tgrep")
          return candidate if File.file?(candidate) && File.executable?(candidate)
        end
        nil
      end

      # PATH binaries are exec'd. A VV_TGREP that is a script without +x
      # (the spec fixture, a checkout of fake-tgrep) is run through ruby so
      # the envelope can be tested on a host that cannot chmod.
      def command(args)
        bin = binary
        return nil if bin.nil?
        return [bin, *args] if File.executable?(bin)

        [RbConfig.ruby, bin, *args]
      end

      def available?
        !binary.nil?
      end

      def index(root:, index_path:)
        Envelope.never_raise("tgrep_failed") do
          unless available?
            return Envelope.refuse(
              "tgrep_missing",
              "tgrep is not on PATH; set VV_TGREP or install https://github.com/microsoft/tgrep (pinned 1.0.8)"
            )
          end

          FileUtils.mkdir_p(index_path)
          status, out, err = run(
            command(["index", File.expand_path(root), "--index-path", File.expand_path(index_path)]),
            timeout: INDEX_TIMEOUT
          )
          return status_to_envelope(status, err, out, action: "index") unless status == :ok

          Envelope.ok(index_path: File.expand_path(index_path), stdout: out, stderr: err)
        end
      end

      def files(root:, index_path: nil)
        Envelope.never_raise("tgrep_failed") do
          unless available?
            return Envelope.refuse(
              "tgrep_missing",
              "tgrep is not on PATH; set VV_TGREP or install https://github.com/microsoft/tgrep (pinned 1.0.8)"
            )
          end

          argv = ["--files"]
          argv += ["--index-path", File.expand_path(index_path)] if index_path
          argv += ["--", File.expand_path(root)]
          status, out, err = run(command(argv), timeout: SEARCH_TIMEOUT)
          # --files with zero paths is still a successful listing. tgrep uses
          # grep exit codes for search, not for listing, but a stand-in may
          # exit 1 on an empty tree; treat that as an empty list, not a miss.
          if status == :ok || (status == :failed && err.to_s.strip.empty?)
            paths = out.each_line.map { |line| relativise(line.strip, root) }.reject(&:empty?)
            return Envelope.ok(paths: paths)
          end

          status_to_envelope(status, err, out, action: "files")
        end
      end

      def search(pattern:, root:, index_path: nil, fixed_strings: true, ignore_case: false, glob: nil, max_count: nil)
        Envelope.never_raise("tgrep_failed") do
          unless available?
            return Envelope.refuse(
              "tgrep_missing",
              "tgrep is not on PATH; set VV_TGREP or install https://github.com/microsoft/tgrep (pinned 1.0.8)"
            )
          end
          if pattern.nil? || pattern.to_s.empty?
            return Envelope.refuse("bad_pattern", "a search pattern is required")
          end

          argv = ["--json"]
          argv += ["--index-path", File.expand_path(index_path)] if index_path
          argv << "-F" if fixed_strings
          argv << "-i" if ignore_case
          Array(glob).each { |g| argv += ["-g", g] }
          argv += ["-m", Integer(max_count).to_s] if max_count
          # AGENTS.md: flags before `--`, then the pattern, then the path.
          # `tgrep serve .` is a subcommand; `tgrep -- serve .` searches for
          # the word. Always `--` so a pattern that looks like a subcommand
          # cannot be misread.
          argv += ["--", pattern.to_s, File.expand_path(root)]

          status, out, err = run(command(argv), timeout: SEARCH_TIMEOUT)
          # Exit 1 is "no matches", not a failure. Same as ripgrep. Collapsing
          # that into tgrep_failed would turn real absence into an error, which
          # is the grep lesson this gem exists to keep honest.
          if status == :ok || (status == :failed && !tgrep_error?(err))
            return Envelope.ok(matches: parse_json_matches(out, root), stderr: err)
          end

          status_to_envelope(status, err, out, action: "search")
        end
      end

      def run(argv, timeout:)
        out = +""
        err = +""
        status = nil

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
              chunk = io.read_nonblock(65_536)
              (io.equal?(stdout) ? out : err) << chunk
            rescue EOFError
              readers.delete(io)
              io.close
            rescue IO::WaitReadable
              nil
            end
          end

          status = wait_thr.value
        end

        return [:missing, out, err] if status.nil?
        return [:ok, out, err] if status.exitstatus == 0
        return [:failed, out, err] if status.exitstatus == 1

        [:error, out, err]
      rescue Errno::ENOENT
        [:missing, "", "tgrep binary disappeared before exec"]
      end

      def status_to_envelope(status, err, out, action:)
        detail = [err, out].map { |s| s.to_s.strip }.reject(&:empty?).first
        case status
        when :missing
          Envelope.refuse("tgrep_missing", "tgrep could not be executed for #{action}")
        when :timeout
          Envelope.refuse("tgrep_failed", "tgrep #{action} exceeded its deadline")
        else
          Envelope.refuse("tgrep_failed", "tgrep #{action} failed#{detail ? ": #{detail.lines.first.strip}" : ""}")
        end
      end

      def tgrep_error?(err)
        text = err.to_s
        return false if text.strip.empty?
        # Warnings (no index, falling back to a scan) arrive with 0 or 1 and
        # are not failures. A regex the engine rejected is.
        text.match?(/error:|invalid regex|unrecognized/i)
      end

      def parse_json_matches(stdout, root)
        stdout.each_line.filter_map do |line|
          line = line.strip
          next if line.empty?

          event = JSON.parse(line)
          next unless event["type"] == "match"

          data = event["data"] || {}
          path = data.dig("path", "text") || data.dig("path", "bytes")
          next if path.nil?

          sub = Array(data["submatches"]).first || {}
          {
            "path" => relativise(path, root),
            "line" => data["line_number"],
            "text" => (data.dig("lines", "text") || "").to_s.chomp,
            "column" => sub["start"]
          }
        rescue JSON::ParserError
          nil
        end
      end

      def relativise(path, root)
        root = File.expand_path(root)
        expanded = begin
          File.expand_path(path, root)
        rescue ArgumentError
          path
        end
        if expanded == root
          path
        elsif expanded.start_with?("#{root}/")
          expanded.delete_prefix("#{root}/")
        else
          path.sub(%r{\A\./}, "")
        end
      end
    end
  end
end
