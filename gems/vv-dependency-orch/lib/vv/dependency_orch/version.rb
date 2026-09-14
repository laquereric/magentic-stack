# frozen_string_literal: true

module Vv
  module DependencyOrch
    # Read from the VERSION file rather than restated here.
    #
    # The gemspec already requires this file, so a literal would put the
    # version in two places -- and this is a gem about exactly that failure:
    # one identity, many placements, and drift is what happens when a declared
    # value and the value actually there stop agreeing. A gem that could not
    # keep its own version in one place would be poor evidence for the rest.
    VERSION = File.read(File.expand_path("../../../VERSION", __dir__)).strip
  end
end
