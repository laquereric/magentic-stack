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
    @error = "BACK unavailable at #{back_url}: #{e.class}"
    @notes = []; @recon = {}
  end

  def create
    cpcp("note.create", { "operationId" => SecureRandom.uuid,
                          "title" => params[:title].to_s, "body" => params[:body].to_s })
    redirect_to root_path
  rescue StandardError
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
