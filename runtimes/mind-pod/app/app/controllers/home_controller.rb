require "net/http"
require "json"

# FRONT role: the browser-facing slice. It holds NO database; it reads and acts
# ONLY through BACK's /_cpcp seam (CPCP). This enforces the boundary by construction.
class HomeController < ApplicationController
  def index
    @notes = cpcp("note.list").dig("result", "@graph") || []
    @recon = cpcp("reconciliation.latest").dig("result") || {}
    @back  = back_url
  rescue StandardError => e
    if defined?(::RailsCpcp::RefusalLog)
      ::RailsCpcp::RefusalLog.record(
        reason: "front_index_failed",
        because: e.class.name,
        source: "front/home#index",
        restoration: {
          "state_reached" => "FRONT rendered without BACK lists",
          "inconsistency" => "the page is empty, not a BACK denial",
          "restore_when" => "note.list and reconciliation.latest succeed",
          "restore_action" => "reload after BACK is up; do not write locally"
        }
      )
    end
    @error = "BACK unavailable at #{back_url}: #{e.class}"
    @notes = []; @recon = {}
  end

  def create
    cpcp("note.create", { "operationId" => SecureRandom.uuid,
                          "title" => params[:title].to_s, "body" => params[:body].to_s })
    redirect_to root_path
  rescue StandardError
    if defined?(::RailsCpcp::RefusalLog)
      ::RailsCpcp::RefusalLog.record(
        reason: "front_create_failed",
        because: "HomeController#create",
        source: "front/home#create",
        restoration: {
          "state_reached" => "FRONT create did not complete a CPCP PUSH",
          "inconsistency" => "the browser may believe a note was submitted",
          "restore_when" => "note.create over /_cpcp succeeds",
          "restore_action" => "retry the submit; FRONT still holds no database"
        }
      )
    end
    redirect_to root_path
  end

  private

  def back_url
    Rails.application.config.x.back_url
  end

  def cpcp(method, params = {})
    uri = URI("#{back_url}/_cpcp/rpc")
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req.body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 10) { |h| h.request(req) }
    JSON.parse(res.body)
  end
end
