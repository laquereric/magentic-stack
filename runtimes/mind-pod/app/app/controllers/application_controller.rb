class ApplicationController < ActionController::Base
  # FRONT is browser-facing; forgery protection off for the demo POST (no user auth).
  skip_forgery_protection if respond_to?(:skip_forgery_protection)
end
