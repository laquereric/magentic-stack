# frozen_string_literal: true
module RailsThreedotBack
  # Shell controller — serves the FRONT webview HTML (thin presentation layer).
  # The webview fetches live CID data via postMessage → CPCP client → /_cpcp.
  class ShellController < ActionController::Base
    layout "rails_threedot_back/shell"

    # GET /threedot/shell
    def index
      # Minimal server-side context; the webview is data-driven via postMessage.
      @timestamp = Time.current.iso8601
    end
  end
end
