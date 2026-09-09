# frozen_string_literal: true

# Internet A2A HTTP surface (CPCP a2a/internet, ADR 0068). ROLE=back only.
# GET /.well-known/agent-card.json and POST /_a2a/rpc.
# 404 unless HTTP_BIND=0.0.0.0 — in-pod loopback does not speak internet A2A.
# Host-published HTTP is a different surface, not a backup path for in-pod
# calls. HTTP is not a fallback. Payloads are the same JSON-LD as intrapod.
class A2aInternetController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)

  def card
    unless RailsCpcp::A2aInternet.speaks?
      head :not_found
      return
    end
    render json: RailsCpcp::A2aInternet.card(base_url: request.base_url), status: :ok
  end

  def rpc
    unless RailsCpcp::A2aInternet.speaks?
      head :not_found
      return
    end
    raw = RailsCpcp::A2aBinding.handle(request.body.read, ctx: self)
    render json: JSON.parse(raw), status: :ok
  end
end
