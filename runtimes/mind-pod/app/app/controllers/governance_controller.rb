# frozen_string_literal: true

# FRONT: DBless ERB projection consumer. Reads only via CPCP PULLs.
class GovernanceController < ApplicationController
  helper_method :governance_items

  def show
    cpcp = BackCpcpClient.new
    cyborg = params[:cyborg_iri].presence || "cyborg:front"

    @notes_envelope = cpcp.pull("note.list")
    @back_available = @notes_envelope["ok"] == true
    @back_url = Rails.application.config.x.back_url
    @cyborg_iri = cyborg

    @channels        = cpcp.pull("l8.cyborg_channel.list", { "cyborg_iri" => cyborg })
    @contexts_all    = cpcp.pull("l8.context.list", { "limit" => 25 })
    @references      = cpcp.pull("l8.reference.list", { "limit" => 50 })
    @routing         = cpcp.pull("l8.routing.list", { "limit" => 50 })
    @journal         = cpcp.pull("l8.operation.journal", { "limit" => 50 })
    @receipts        = cpcp.pull("l8.execution.receipt.list", { "limit" => 50 })
    @biography       = cpcp.pull("l8.biography.get", { "subject_iri" => cyborg, "limit" => 50 })
    @provenance_all  = cpcp.pull("l8.provenance.list", { "limit" => 50 })
    @authorization   = cpcp.pull("l8.authorization.list", { "limit" => 50 })
    @observations    = cpcp.pull("l8.observation.list", { "limit" => 50 })
    @outcomes        = cpcp.pull("l8.outcome.list", { "limit" => 50 })
    @learning        = cpcp.pull("l8.learning.list", { "limit" => 50 })
    @drift           = cpcp.pull("l8.drift.list", { "limit" => 50 })
    @p9_contract     = cpcp.pull("ux.profile.describe")
  end


  private

  def governance_items(envelope)
    return [] unless envelope.is_a?(Hash) && envelope["ok"] == true

    result = envelope["result"]
    return result["@graph"] if result.is_a?(Hash) && result["@graph"].is_a?(Array)
    return result if result.is_a?(Array)

    []
  end
end
