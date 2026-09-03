# frozen_string_literal: true

# ROLE=config switch display. The browser surface for sources, pins,
# refresh, verify, and test now that `:13001` is headed for retirement
# (row 11 slices B–C). Calls switch server-side; a switch refusal is
# designed behaviour, not an error path: surface reason and because
# (gap 104). Verify/test are billed and slow — on demand with confirm,
# never on page load.
module ConfigAdmin
class SwitchController < ActionController::Base
  skip_forgery_protection if respond_to?(:skip_forgery_protection)
  layout "config"

  def index
    got = client.sources
    @vendors = got["ok"] ? got.dig("result", "vendors") || [] : []
    @active = got.dig("result", "active")
    @refusal = got["ok"] ? nil : got
    @result = nil
  end

  def update
    result = client.update(update_params)
    if result["ok"]
      redirect_to switch_path
    else
      @vendors = []
      @active = nil
      @refusal = result
      @result = nil
      render :index, status: :unprocessable_entity
    end
  end

  def refresh
    @result = client.refresh(params[:vendor].to_s)
    @refusal = @result["ok"] ? nil : @result
    reload_sources
    render :index, status: @refusal ? :unprocessable_entity : :ok
  end

  def verify
    @result = client.verify(vendor: params[:vendor], pin: params[:pin])
    @refusal = @result["ok"] ? nil : @result
    reload_sources
    render :index, status: @refusal ? :unprocessable_entity : :ok
  end

  def test
    @result = client.test(params[:pin].to_s)
    @refusal = @result["ok"] ? nil : @result
    reload_sources
    render :index, status: @refusal ? :unprocessable_entity : :ok
  end

  private

  def reload_sources
    got = client.sources
    @vendors = got["ok"] ? got.dig("result", "vendors") || [] : []
    @active = got.dig("result", "active")
  end

  # Pins, toggles, prices only. Key material has no param here by design
  # (vault UI owns keys since slice A); anything else is dropped, not
  # forwarded.
  def update_params
    params.permit(:active, :routerPin, :pin, :enabled, price: %i[in out]).to_h.compact
  end

  def client
    @client ||= SwitchClient.new(base_url: ENV.fetch("SWITCH_UI_URL"))
  end
end
end
