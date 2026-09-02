# frozen_string_literal: true

# ROLE=shape v1 retrieval surface (ADR 0049 / ROLE_SHAPE.md §2).
# GET /_cpcp/up, GET /_cpcp/shapes.json, GET /_cpcp/shapes/sha256:<digest>.
# Do NOT mount RailsCpcp::Engine: stock engine draws POST rpc and BACK's
# note.create catalog. POST rpc is not in v1. Enforcement stays in BACK.
class ShapeController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)

  def up
    surface = ShapeSurface.new
    render json: {
      "ok" => true,
      "role" => "shape",
      "artifacts" => surface.artifacts,
      "operations" => []
    }, status: :ok
  end

  def index
    render json: ShapeSurface.document, status: :ok
  end

  def show
    bytes = ShapeSurface.new.turtle(params[:digest].to_s)
    if bytes.nil?
      head :not_found
      return
    end
    render body: bytes, content_type: "text/turtle", status: :ok
  end
end
