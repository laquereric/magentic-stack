# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "vv-code-search"
require "tmpdir"
require "fileutils"

module CorpusHelpers
  # The real monorepo. These specs index THIS tree rather than a fixture for the
  # bound to mean anything: "p95 under a second" over six invented files proves
  # nothing about the corpus the gem exists to serve.
  REPO_ROOT = File.expand_path("../../..", __dir__)

  def repo_root = REPO_ROOT

  def with_store
    Dir.mktmpdir("vv-code-search") { |dir| yield dir }
  end

  # A small synthetic tree, for the cases where the assertion is about exact
  # postings and the real repo would make the expectation a moving target.
  def with_corpus(files)
    Dir.mktmpdir("corpus") do |dir|
      files.each do |path, body|
        full = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.binwrite(full, body)
      end
      yield dir
    end
  end

  FAKE_TGREP = File.expand_path("fixtures/fake-tgrep", __dir__)

  # The gem discovers tgrep on PATH. Specs that assert the envelope around it
  # must not depend on a Microsoft binary being installed, so they point
  # VV_TGREP at the contract double in spec/fixtures.
  def with_tgrep
    File.chmod(0o755, FAKE_TGREP)
    previous = ENV["VV_TGREP"]
    ENV["VV_TGREP"] = FAKE_TGREP
    yield
  ensure
    previous.nil? ? ENV.delete("VV_TGREP") : ENV["VV_TGREP"] = previous
  end

  # Hide both VV_TGREP and PATH so Tgrep.available? is false. Needed to prove
  # the tgrep_missing refusal -- a host with a real tgrep would otherwise
  # silently take the success path and the plant would have nothing to catch.
  def without_tgrep
    previous = ENV["VV_TGREP"]
    previous_path = ENV["PATH"]
    ENV.delete("VV_TGREP")
    ENV["PATH"] = "/nonexistent"
    yield
  ensure
    previous.nil? ? ENV.delete("VV_TGREP") : ENV["VV_TGREP"] = previous
    ENV["PATH"] = previous_path if previous_path
  end
end

RSpec.configure do |config|
  config.include CorpusHelpers
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
