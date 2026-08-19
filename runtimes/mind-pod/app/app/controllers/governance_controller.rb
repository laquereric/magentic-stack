# frozen_string_literal: true

# FRONT: DBless ERB projection consumer. Reads only via CPCP PULLs.
class GovernanceController < ApplicationController
  helper_method :governance_items

  def show
    cpcp = BackCpcpClient.new
    cyborg = params[:cyborg_iri].presence || "cyborg:front"

    # Milestone 0 shell: BACK availability via existing note.list
    @notes_envelope = cpcp.pull("note.list")
    @back_available = @notes_envelope["ok"] == true
    @back_url = Rails.application.config.x.back_url
    @cyborg_iri = cyborg

    # Milestone 1 panels 1 + 4
    @channels   = cpcp.pull("l8.cyborg_channel.list", { "cyborg_iri" => cyborg })
    @contexts   = cpcp.pull("l8.context.list", { "subject_iri" => cyborg, "limit" => 25 })
    # Contexts may also be subject-scoped to mind:pod — pull a broader list too
    @contexts_all = cpcp.pull("l8.context.list", { "limit" => 25 })
    @journal    = cpcp.pull("l8.operation.journal", { "limit" => 50 })
    @receipts   = cpcp.pull("l8.execution.receipt.list", { "limit" => 50 })
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
