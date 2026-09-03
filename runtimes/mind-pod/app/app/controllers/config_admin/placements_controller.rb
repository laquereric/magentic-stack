# frozen_string_literal: true

# ROLE=config placement UI. Persist's first caller (row 41). Lists the
# recorded next-boot intention per store and records new ones. Path
# options come from the row-39 closed set (config/store_bindings.json),
# never free text — an open-set path is an arbitrary-file-write primitive
# (0051 section 1). Recording is not applying: persist answers
# live_applied:false and a restart applies (ROW41 S2). A persist 403/401
# is designed behaviour, not an error path: surface reason and because
# (gap 104).
module ConfigAdmin
class PlacementsController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)
  layout "config"

  def index
    @sets = closed_sets
    @rows = @sets.map do |id, _|
      got = client.get(id)
      { "store" => id, "placement" => got["ok"] ? got["result"] : nil, "refusal" => got["ok"] ? nil : got }
    end
    @refusal = nil
  rescue Persist::ClosedSet::Error => e
    @sets = {}
    @rows = []
    @refusal = { "ok" => false, "reason" => e.reason, "because" => e.because, "status" => 500 }
  end

  def create
    store = params[:store].to_s
    path = params[:path].to_s
    result = client.set(store, path)
    if result["ok"]
      redirect_to placements_path
    else
      @sets = closed_sets
      @rows = []
      @refusal = result
      render :index, status: :unprocessable_entity
    end
  end

  private

  def closed_sets
    Persist::ClosedSet.read!
  end

  def client
    @client ||= PersistClient.new(
      base_url: ENV.fetch("PERSIST_URL"),
      token: ENV.fetch("PERSIST_TOKEN"),
    )
  end
end
end
