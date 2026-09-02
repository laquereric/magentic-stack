# frozen_string_literal: true

# ROLE=config catalogue UI. Display only. Does not discover, verify,
# egress, or read a secret (ADR 0046 / row 15). Discovery and verify
# stay with switch/router, which holds state.keys.
module ConfigAdmin
class CatalogController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)
  layout "config"

  def index
    @catalog = Catalog.load
    respond_to do |format|
      format.html
      format.json { render json: { "ok" => true, "owned_by" => @catalog.owned_by, "vendors" => @catalog.vendors } }
    end
  end
end
end
