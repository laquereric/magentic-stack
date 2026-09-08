# frozen_string_literal: true

require "rspec"
require_relative "../lib/rails-osi-level-8"

# REQUIRED HERE, NOT BY THE GEM.
#
# translation_board.rb requires mmg-semantic-editor lazily, inside the edit
# projection, so that consumers who render no board never inherit it. The specs
# reach CanonicalId and Prose directly -- including to cross-check that the
# board's own editable? predicate still agrees with the editor's rule -- so they
# load it themselves. A path gem in this Gemfile, never a runtime dependency.
require "mmg-semantic-editor"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
