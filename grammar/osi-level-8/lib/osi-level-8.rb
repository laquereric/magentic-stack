# frozen_string_literal: true

require_relative "osi/level8/version"

# OSI Level 8 — the Cybernetic Interface.
#
# This gem is SPEC-FIRST (like json-rpc-ld): the normative artifacts are the
# specification document under docs/ and the SHACL shapes under shapes/ that
# constrain the interface. Any Ruby here is a thin reference surface, not the
# authority.
#
#   Cyborg  <-reads-  Context      (perception)
#   Cyborg  -has->     Effect       (action)
#
# The Cyborg = a responsible Human + Compute Machinery (relational DBs, graph
# DBs, LLMs). Profile 1 is the vv-graph relational/graph model: every triple is
# grounded on a class or an instance.
module Osi
  module Level8
    # Location of the normative SHACL shapes shipped with this gem.
    SHAPES_DIR = File.expand_path("../shapes", __dir__)

    def self.shapes_dir = SHAPES_DIR
  end
end
