# frozen_string_literal: true

require "mmg/acia/version"
require "mmg/acia/engine"
require "mmg/acia/markdown"
require "mmg/acia/tree"

# mmg-acia -- the ACIA CORE MODEL (epic_65), extracted from mmg-sal.
#
#   tree model      = AR ancestry hierarchy   (app/models/mmg/acia/node.rb -> Mmg::Acia::Node)
#   builders        = domain -> host-agnostic node hash (lib/mmg/acia/tree.rb -> Mmg::Acia::Tree)
#   materialization = node tree -> durable .md (lib/mmg/acia/markdown.rb -> Mmg::Acia::Markdown)
#   graph           = projection + mm: refs (app/services/mmg/acia/graph.rb, urn:mm:vocab/acia#)
#
# ACIA is the canonical tree an operation produces ("ACIA OUT") and consumes ("ACIA IN").
# SAL and the host gems (mmg-tmux, mmg-web) DELIVER an ACIA-based UX on top of this core;
# LLM consumption of ACIA trees is a SEPARABLE concern (Mmg::Acia::Op, later). This gem is
# a LEAF: it owns the ACIA tree primitive, not federation.
#
# Stage 1 (scaffold): the engine mounts empty; behavior is moved in from mmg-sal in Stage 2.
module Mmg
  module Acia
  end
end
