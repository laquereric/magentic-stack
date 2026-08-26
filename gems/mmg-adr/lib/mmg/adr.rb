# frozen_string_literal: true

require_relative "adr/version"
require_relative "adr/vocabulary"
require_relative "adr/document"
require_relative "adr/projection"
require_relative "adr/chain"

# mmg-adr -- ADR-as-spec. Decision records as STATE the fleet reads, not
# presentation a human is trusted to have read.
#
# A rule an agent never reads is operationally dead. The files under docs/adr are
# what an agent reads; the row and the grounded graph here are what makes the
# ledger queryable -- so "which accepted decisions govern this path, and which of
# them name no enforcing test" has an answer.
#
# Loading this gem pulls in the pure half only: parse, project, check. Record and
# Ingest need ActiveRecord and are autoloaded by the engine inside a Rails app,
# which keeps `require "mmg-adr"` safe in a plain Ruby process.
module Mmg
  module Adr
    module_function

    # Where the decisions live. One home, because the same rule written into
    # three files for three tools drifts at three different rates and the agent
    # that lands on the oldest copy behaves the way the oldest copy says.
    ADR_DIR = "docs/adr"

    def adr_dir(repo_root) = File.join(repo_root.to_s, ADR_DIR)
  end
end
