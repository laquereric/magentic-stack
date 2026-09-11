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
        File.write(full, body)
      end
      yield dir
    end
  end
end

RSpec.configure do |config|
  config.include CorpusHelpers
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
