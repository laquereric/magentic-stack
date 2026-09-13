# frozen_string_literal: true
# Compatibility shim for mmg-browser requires.
require_relative "vv/browser"
module Mmg
  Browser = ::Vv::Browser unless const_defined?(:Browser, false)
end
