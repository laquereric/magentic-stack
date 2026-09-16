# frozen_string_literal: true

module Vv
  module Nooa
    # One NOOA harness capability, plus how magentic-stack realizes it and the
    # portable lesson to "steal" even without installing NOOA.
    Capability = Struct.new(:key, :title, :nvidia, :mm, :steal, keyword_init: true)
  end
end
