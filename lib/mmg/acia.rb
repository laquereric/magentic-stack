# frozen_string_literal: true

require "mmg/acia/version"
require "mmg/acia/markdown"
require "mmg/acia/tree"
require "mmg/acia/state"
require "mmg/acia/transition"
require "mmg/acia/validated_snapshot"
require "mmg/acia/tab_tree"

# Rails engine is optional for pure Tree/State specs; load when Rails is present.
begin
  require "mmg/acia/engine" if defined?(::Rails)
rescue ::LoadError
end

# mmg-acia -- the ACIA CORE MODEL (epic_65), extracted from mmg-sal.
#
#   tree model      = AR ancestry hierarchy   (app/models/mmg/acia/node.rb -> Mmg::Acia::Node)
#   builders        = domain -> host-agnostic node hash (lib/mmg/acia/tree.rb -> Mmg::Acia::Tree)
#   materialization = node tree -> durable .md (lib/mmg/acia/markdown.rb -> Mmg::Acia::Markdown)
#   graph           = projection + mm: refs (app/services/mmg/acia/graph.rb, urn:mm:vocab/acia#)
#   Phase B state   = State registry + Transition + ValidatedSnapshot (enforce path)
#
# ACIA is the canonical tree an operation produces ("ACIA OUT") and consumes ("ACIA IN").
# SAL and the host gems (mmg-tmux, mmg-web) DELIVER an ACIA-based UX on top of this core;
# LLM consumption of ACIA trees is a SEPARABLE concern (later gem). This gem is a LEAF.
module Mmg
  module Acia
    module_function

    def version = VERSION

    def normalize_state(role, state) = State.normalize(role, state)
    def validate_tree_state(tree) = State.validate_tree(tree)
    def select_tab(tree, **kwargs) = Transition.select_tab(tree, **kwargs)
    def validated_snapshot(tree, **kwargs) = ValidatedSnapshot.from_tree(tree, **kwargs)
    def select_and_validate(tree, **kwargs) = ValidatedSnapshot.select_and_validate(tree, **kwargs)
    def sample_tab_tree(**kwargs) = TabTree.sample(**kwargs)
  end
end
