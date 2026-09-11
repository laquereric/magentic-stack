# frozen_string_literal: true

require_relative "code_search/version"
require_relative "code_search/envelope"
require_relative "code_search/dimension"
require_relative "code_search/dimensions/pins"
require_relative "code_search/dimensions/lexical"
require_relative "code_search/schema"
require_relative "code_search/index"
require_relative "code_search/lookup"

module Vv
  # Pre-calculated, per-line search over trees we already host.
  #
  # See docs/architecture/plan_vv-code-search.md. The short version: grep is the
  # right primitive for a COLD tree, and reconstructing the same edges on every
  # agent turn is the waste. This gem does not try to stop agents grepping trees
  # nobody has indexed. It makes KNOWN trees stop being unknown every time.
  #
  # Private gem. Not on rubygems.org.
  module CodeSearch
    # The families that ship. A family is a claim about a KIND of tree, not
    # about one repo -- `magentic` covers this monorepo and the gem galaxy
    # beside it because they pin the same way (Gemfile.lock, pin manifests,
    # submodule gitlinks, digest-pinned images).
    #
    # Structural (tree-sitter AST) is deliberately absent. It is not an
    # oversight and not a stage-ordering choice: plan_vv-code-search lists
    # "whether mm-pattern-tree-sitter is consumed or retired" as an OWNER
    # decision, under the rule that there is to be one structural index rather
    # than a third. Registering a structural dimension here would make that
    # decision by shipping, so the dimension waits for the call.
    Schema.register(
      id: "magentic",
      dimensions: [Dimensions::Pins, Dimensions::Lexical],
      why: "Ruby gem galaxy plus pin-JSON CR tree: Gemfile.lock, upstreams/manifests/*.pin.json, " \
           ".gitmodules, base_image_digests.json, and digest-pinned compose images."
    )

    # Pins only. The stage-1 shape from the plan, and the one a maintainer wants
    # on an incoming PR: build it in a fraction of the time when the question is
    # only ever "which pin does this line belong to".
    Schema.register(
      id: "magentic-pins",
      dimensions: [Dimensions::Pins],
      why: "Stage 1: the pin dimension alone, for PR-time blast-radius questions."
    )
  end
end
